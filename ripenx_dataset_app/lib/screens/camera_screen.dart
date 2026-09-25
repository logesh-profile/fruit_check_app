import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../services/dataset_service.dart';
import '../theme/app_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.fruit,
    required this.variety,
    this.varietyDirectoryPath,
  });

  final String fruit;
  final String variety;
  final String? varietyDirectoryPath;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  int _photoCount = 0;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  bool _isPermissionError = false;
  bool _showFlash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CameraService.disposeController(_controller);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Free camera hardware when not in foreground
      CameraService.disposeController(controller);
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize camera on returning to foreground
      _initCamera();
    }
  }

  Future<void> _initializeScreen() async {
    await _resolvePhotoCount();
    await _initCamera();
  }

  Future<void> _resolvePhotoCount() async {
    try {
      final count = await DatasetService.countPhotos(
        widget.fruit,
        widget.variety,
      );
      if (mounted) setState(() => _photoCount = count);
    } catch (_) {
      // Fallback count
    }
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _isPermissionError = false;
    });

    try {
      final controller = await CameraService.initializeCamera();
      if (!mounted) {
        await CameraService.disposeController(controller);
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } on CameraServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = e.message;
        _isPermissionError = e.isPermissionDenied;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Unable to initialize camera: $e';
        _isPermissionError = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _showFlash = true;
    });

    // Reset visual flash after 100ms
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showFlash = false);
    });

    try {
      final xFile = await controller.takePicture();
      await DatasetService.saveCapturedPhoto(
        fruit: widget.fruit,
        variety: widget.variety,
        capturedFile: xFile,
      );

      final newCount = await DatasetService.countPhotos(
        widget.fruit,
        widget.variety,
      );
      if (mounted) {
        setState(() {
          _photoCount = newCount;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save photo: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _CameraAppBar(fruit: widget.fruit, variety: widget.variety),
      body: SafeArea(
        child: Column(
          children: [
            // ── Camera viewport area ──────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildCameraViewport(),
              ),
            ),

            // ── Controls & photo count ───────────────────────────────────
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraViewport() {
    if (_isInitializing) {
      return _buildPlaceholder(
        icon: Icons.camera_alt_outlined,
        title: 'Initializing Camera...',
        subtitle: 'Please wait a moment',
        showSpinner: true,
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _buildPlaceholder(
        icon: Icons.videocam_off_outlined,
        title: 'Camera Unavailable',
        subtitle: 'Camera is not active',
        actionLabel: 'Retry',
        onAction: _initCamera,
      );
    }

    // Live preview with flash overlay
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: CameraPreview(controller),
            ),

            // Subtle shutter flash feedback
            if (_showFlash)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 90),
                opacity: _showFlash ? 0.7 : 0.0,
                child: Container(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPermissionError
                  ? AppTheme.accent.withValues(alpha: 0.1)
                  : AppTheme.error.withValues(alpha: 0.1),
            ),
            child: Icon(
              _isPermissionError
                  ? Icons.no_photography_outlined
                  : Icons.error_outline_rounded,
              size: 32,
              color: _isPermissionError ? AppTheme.accent : AppTheme.error,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _isPermissionError ? 'Camera Permission Required' : 'Camera Unavailable',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Unable to start camera preview.',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initCamera,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceAlt,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showSpinner = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: AppTheme.accent,
                strokeWidth: 2.5,
              ),
            ),
          ] else ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.textMuted.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 30,
                color: AppTheme.textMuted.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    final canCapture = _controller != null &&
        _controller!.value.isInitialized &&
        !_isCapturing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          // Shutter button
          GestureDetector(
            onTap: canCapture ? _capturePhoto : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: canCapture ? 1.0 : 0.45,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accent,
                    ),
                    child: _isCapturing
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppTheme.background,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            color: AppTheme.background,
                            size: 26,
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Photo count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Photos captured: $_photoCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App bar ─────────────────────────────────────────────────────────────────

class _CameraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CameraAppBar({required this.fruit, required this.variety});
  final String fruit;
  final String variety;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppTheme.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: fruit,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const TextSpan(
              text: '  •  ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AppTheme.textMuted,
              ),
            ),
            TextSpan(
              text: variety,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }
}

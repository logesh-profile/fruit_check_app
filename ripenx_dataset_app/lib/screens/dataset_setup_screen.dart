import 'package:flutter/material.dart';
import '../services/dataset_service.dart';
import '../services/storage_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// First-launch screen that guides the user to select their FRUIT_DATASET
/// root folder. Not shown again once a valid root has been saved.
class DatasetSetupScreen extends StatefulWidget {
  const DatasetSetupScreen({super.key});

  @override
  State<DatasetSetupScreen> createState() => _DatasetSetupScreenState();
}

class _DatasetSetupScreenState extends State<DatasetSetupScreen> {
  /// The picked dataset root metadata.
  PickedDatasetRoot? _selectedRoot;

  /// Whether the last picked folder had an invalid name.
  bool _isInvalidName = false;

  /// Whether the folder picker is currently open.
  bool _isPicking = false;

  // ── Derived ──────────────────────────────────────────────────────────────

  String? get _folderName => _selectedRoot?.name;

  bool get _isValid =>
      _selectedRoot != null &&
      _selectedRoot!.name == DatasetService.expectedRootName;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickFolder() async {
    setState(() {
      _isPicking = true;
      _isInvalidName = false;
    });

    try {
      final picked = await DatasetService.pickDatasetRoot();

      if (!mounted) return;

      if (picked == null) {
        // User cancelled
        setState(() => _isPicking = false);
        return;
      }

      final valid = picked.name == DatasetService.expectedRootName;
      setState(() {
        _selectedRoot = picked;
        _isInvalidName = !valid;
        _isPicking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPicking = false);
    }
  }

  Future<void> _onContinue() async {
    if (!_isValid || _selectedRoot == null) return;
    await DatasetService.initializeDatasetRoot(_selectedRoot!);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                // ── Branding ─────────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.2),
                        AppTheme.accentDark.withValues(alpha: 0.03),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    size: 36,
                    color: AppTheme.accent,
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'RIPENX',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Dataset Setup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Choose the root folder for your fruit\nimage dataset.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppTheme.textMuted,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Folder pick button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isPicking ? null : _pickFolder,
                    icon: _isPicking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          )
                        : const Icon(Icons.folder_rounded,
                            color: AppTheme.accent),
                    label: Text(
                      _isPicking
                          ? 'Opening picker…'
                          : 'Select FRUIT_DATASET Folder',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.accent.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Selection result ──────────────────────────────────────
                if (_selectedRoot != null) ...[
                  _SelectionResult(
                    folderName: _folderName!,
                    isValid: _isValid,
                    isInvalidName: _isInvalidName,
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Continue button ───────────────────────────────────────
                if (_isValid) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      style: AppTheme.primaryButton(),
                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Selection result card ────────────────────────────────────────────────────

class _SelectionResult extends StatelessWidget {
  const _SelectionResult({
    required this.folderName,
    required this.isValid,
    required this.isInvalidName,
  });

  final String folderName;
  final bool isValid;
  final bool isInvalidName;

  @override
  Widget build(BuildContext context) {
    final color = isValid ? AppTheme.accent : const Color(0xFFE74C3C);
    final icon =
        isValid ? Icons.check_circle_rounded : Icons.error_rounded;
    final message = isInvalidName
        ? 'Please select or create a folder named FRUIT_DATASET.'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Selected folder',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            folderName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFE74C3C),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

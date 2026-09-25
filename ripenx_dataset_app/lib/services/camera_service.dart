import 'package:camera/camera.dart';

/// Exceptions originating from the camera lifecycle or hardware access.
class CameraServiceException implements Exception {
  CameraServiceException(this.message, {this.isPermissionDenied = false});
  final String message;
  final bool isPermissionDenied;

  @override
  String toString() => message;
}

/// Helper service for managing camera discovery, initialization, and disposal.
abstract final class CameraService {
  /// Discovers available device cameras and initializes the primary (back/rear) camera.
  ///
  /// Throws [CameraServiceException] with user-friendly descriptions on failure or permission denial.
  static Future<CameraController> initializeCamera({
    CameraLensDirection preferredDirection = CameraLensDirection.back,
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      final isPermission = e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted';
      throw CameraServiceException(
        isPermission
            ? 'Camera permission is required to capture fruit images.'
            : 'Unable to access cameras: ${e.description ?? e.code}',
        isPermissionDenied: isPermission,
      );
    } catch (e) {
      throw CameraServiceException('Unable to check available cameras: $e');
    }

    if (cameras.isEmpty) {
      throw CameraServiceException('No camera found on this device.');
    }

    // Select preferred lens direction (rear camera for dataset photography)
    final selectedCamera = cameras.firstWhere(
      (c) => c.lensDirection == preferredDirection,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selectedCamera,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      final isPermission = e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted';
      throw CameraServiceException(
        isPermission
            ? 'Camera permission is required to capture fruit images.'
            : 'Failed to initialize camera: ${e.description ?? e.code}',
        isPermissionDenied: isPermission,
      );
    } catch (e) {
      await controller.dispose();
      throw CameraServiceException('Failed to initialize camera: $e');
    }

    return controller;
  }

  /// Safely disposes a [CameraController] if it is initialized.
  static Future<void> disposeController(CameraController? controller) async {
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }
}

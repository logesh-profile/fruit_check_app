import 'dart:io';
import 'package:camera/camera.dart';
import 'dataset_service.dart';
import 'file_naming_service.dart';

/// Service responsible for persisting captured images into the fruit dataset directory.
abstract final class ImageStorageService {
  /// Saves a [capturedFile] (from Camera plugin) for the given [fruit] and [variety]
  /// using the next sequential filename (e.g. `photo_001.jpg`).
  ///
  /// Guarantees that existing images are never overwritten.
  /// Works across both Android SAF and standard filesystems.
  static Future<String> saveCapturedImage({
    required XFile capturedFile,
    required String fruit,
    required String variety,
  }) async {
    return DatasetService.saveCapturedPhoto(
      fruit: fruit,
      variety: variety,
      capturedFile: capturedFile,
    );
  }

  /// Legacy helper for direct Directory saves (used in unit tests).
  static Future<File> saveCapturedImageToDirectory({
    required XFile capturedFile,
    required Directory destinationDirectory,
  }) async {
    if (!await destinationDirectory.exists()) {
      await destinationDirectory.create(recursive: true);
    }

    final targetPath = await FileNamingService.getNextPhotoPath(destinationDirectory);
    final targetFile = File(targetPath);

    if (await targetFile.exists()) {
      throw StateError('Target file "$targetPath" already exists.');
    }

    final bytes = await capturedFile.readAsBytes();
    await targetFile.writeAsBytes(bytes, flush: true);

    return targetFile;
  }
}

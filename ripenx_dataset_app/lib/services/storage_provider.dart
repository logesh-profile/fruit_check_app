import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

/// Metadata for a picked dataset root directory.
class PickedDatasetRoot {
  const PickedDatasetRoot({
    required this.identifier,
    required this.name,
    required this.isSaf,
  });

  /// The persistent identifier (Android SAF Document Tree URI, or filesystem path on iOS/Desktop).
  final String identifier;

  /// The folder name (e.g. `FRUIT_DATASET`).
  final String name;

  /// Whether this identifier is an Android SAF content URI.
  final bool isSaf;
}

/// Abstract storage provider interface decoupling dataset operations from platform-specific APIs.
abstract class DatasetStorageProvider {
  /// Prompts the user to select the dataset root folder using the platform-appropriate picker.
  Future<PickedDatasetRoot?> pickDatasetRoot();

  /// Verifies that access to the given [rootIdentifier] is still valid and not revoked.
  Future<bool> hasValidAccess(String rootIdentifier);

  /// Lists all filenames present in `FRUIT_DATASET/<fruit>/<variety>/`.
  Future<List<String>> listPhotoFilenames({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  });

  /// Writes captured JPEG image [bytes] to `FRUIT_DATASET/<fruit>/<variety>/<filename>`.
  /// Returns the saved URI or path string.
  Future<String> saveImageBytes({
    required String rootIdentifier,
    required String fruit,
    required String variety,
    required String filename,
    required Uint8List bytes,
  });

  /// Ensures that the fruit and variety subfolders are prepared.
  Future<void> prepareVarietyFolder({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  });
}

/// Android Storage Access Framework (SAF) document-tree storage provider.
class SafStorageProvider implements DatasetStorageProvider {
  SafStorageProvider({
    SafUtil? safUtil,
    SafStream? safStream,
  })  : _safUtil = safUtil ?? SafUtil(),
        _safStream = safStream ?? SafStream();

  final SafUtil _safUtil;
  final SafStream _safStream;

  @override
  Future<PickedDatasetRoot?> pickDatasetRoot() async {
    final picked = await _safUtil.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (picked == null) return null;

    return PickedDatasetRoot(
      identifier: picked.uri,
      name: picked.name,
      isSaf: true,
    );
  }

  @override
  Future<bool> hasValidAccess(String rootIdentifier) async {
    try {
      final hasPermission = await _safUtil.hasPersistedPermission(rootIdentifier);
      if (!hasPermission) return false;
      return await _safUtil.exists(rootIdentifier, true);
    } catch (_) {
      return false;
    }
  }

  /// Resolves or creates the variety directory URI under `FRUIT_DATASET/<fruit>/<variety>/`.
  Future<String> _getOrCreateVarietyDirectoryUri({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {
    final rootEntries = await _safUtil.list(rootIdentifier);
    dynamic fruitDoc;
    for (final doc in rootEntries) {
      if (doc.isDir && doc.name.toLowerCase() == fruit.toLowerCase()) {
        fruitDoc = doc;
        break;
      }
    }

    if (fruitDoc != null) {
      final fruitEntries = await _safUtil.list(fruitDoc.uri as String);
      dynamic varietyDoc;
      for (final doc in fruitEntries) {
        if (doc.isDir && doc.name.toLowerCase() == variety.toLowerCase()) {
          varietyDoc = doc;
          break;
        }
      }
      if (varietyDoc != null) {
        return varietyDoc.uri as String;
      }
    }

    // Create intermediate directories explicitly if not already present
    final created = await _safUtil.mkdirp(rootIdentifier, [fruit, variety]);
    return created.uri;
  }

  @override
  Future<List<String>> listPhotoFilenames({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {
    try {
      final rootEntries = await _safUtil.list(rootIdentifier);
      dynamic fruitDoc;
      for (final doc in rootEntries) {
        if (doc.isDir && doc.name.toLowerCase() == fruit.toLowerCase()) {
          fruitDoc = doc;
          break;
        }
      }
      if (fruitDoc == null) return [];

      final fruitEntries = await _safUtil.list(fruitDoc.uri as String);
      dynamic varietyDoc;
      for (final doc in fruitEntries) {
        if (doc.isDir && doc.name.toLowerCase() == variety.toLowerCase()) {
          varietyDoc = doc;
          break;
        }
      }
      if (varietyDoc == null) return [];

      final varietyEntries = await _safUtil.list(varietyDoc.uri as String);
      return varietyEntries
          .where((doc) => !doc.isDir)
          .map((doc) => doc.name)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> saveImageBytes({
    required String rootIdentifier,
    required String fruit,
    required String variety,
    required String filename,
    required Uint8List bytes,
  }) async {
    // 1. Explicitly resolve the variety directory URI
    final varietyDirectoryUri = await _getOrCreateVarietyDirectoryUri(
      rootIdentifier: rootIdentifier,
      fruit: fruit,
      variety: variety,
    );

    // 2. Write JPEG image directly into the variety directory
    final result = await _safStream.writeFileBytes(
      varietyDirectoryUri,
      filename,
      'image/jpeg',
      bytes,
    );
    return result.uri.toString();
  }

  @override
  Future<void> prepareVarietyFolder({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {
    final valid = await hasValidAccess(rootIdentifier);
    if (!valid) {
      throw StateError('Dataset folder access expired. Please select FRUIT_DATASET again.');
    }

    // Ensure the variety directory exists on the SAF document tree
    await _getOrCreateVarietyDirectoryUri(
      rootIdentifier: rootIdentifier,
      fruit: fruit,
      variety: variety,
    );
  }
}

/// Standard file-system storage provider for iOS, Desktop, and Unit Tests.
class FileSystemStorageProvider implements DatasetStorageProvider {
  @override
  Future<PickedDatasetRoot?> pickDatasetRoot() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select FRUIT_DATASET folder',
    );
    if (path == null) return null;

    final name = path
        .replaceAll(r'\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .lastOrNull ??
        '';

    return PickedDatasetRoot(
      identifier: path,
      name: name,
      isSaf: false,
    );
  }

  @override
  Future<bool> hasValidAccess(String rootIdentifier) async {
    try {
      final dir = Directory(rootIdentifier);
      return await dir.exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> listPhotoFilenames({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {
    try {
      final cleanRoot = rootIdentifier.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
      final varietyPath = '$cleanRoot/$fruit/$variety';
      final varietyDir = Directory(varietyPath);
      if (!await varietyDir.exists()) return [];

      final filenames = <String>[];
      await for (final entity in varietyDir.list(followLinks: false)) {
        if (entity is File) {
          final basename = entity.path
              .replaceAll(r'\', '/')
              .split('/')
              .where((s) => s.isNotEmpty)
              .last;
          filenames.add(basename);
        }
      }
      return filenames;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> saveImageBytes({
    required String rootIdentifier,
    required String fruit,
    required String variety,
    required String filename,
    required Uint8List bytes,
  }) async {
    final cleanRoot = rootIdentifier.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    final varietyPath = '$cleanRoot/$fruit/$variety';
    final varietyDir = Directory(varietyPath);
    if (!await varietyDir.exists()) {
      await varietyDir.create(recursive: true);
    }

    final targetFile = File('$varietyPath/$filename');
    if (await targetFile.exists()) {
      throw StateError('Target file "${targetFile.path}" already exists.');
    }

    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }

  @override
  Future<void> prepareVarietyFolder({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {
    final cleanRoot = rootIdentifier.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    final varietyPath = '$cleanRoot/$fruit/$variety';
    final varietyDir = Directory(varietyPath);
    if (!await varietyDir.exists()) {
      await varietyDir.create(recursive: true);
    }
  }
}

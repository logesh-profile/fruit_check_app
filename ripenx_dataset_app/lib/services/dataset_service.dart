import 'dart:io';
import 'package:camera/camera.dart';
import 'file_naming_service.dart';
import 'storage_provider.dart';
import 'storage_service.dart';

/// Business logic for the RIPENX dataset folder hierarchy and storage access.
///
/// Hierarchy:
///   FRUIT_DATASET/
///     ├── Mango/
///     │   ├── Banganapalli/
///     │   │   ├── photo_001.jpg
///     │   │   ├── photo_002.jpg
///     │   │   └── ...
///     │   ├── Totapuri/
///     │   └── Alphonso/
///     ├── Banana/
///     │   └── Robusta/
///     └── ...
abstract final class DatasetService {
  /// The required folder name for the dataset root.
  static const String expectedRootName = 'FRUIT_DATASET';

  static DatasetStorageProvider _defaultProvider() {
    return Platform.isAndroid
        ? SafStorageProvider()
        : FileSystemStorageProvider();
  }

  static DatasetStorageProvider _provider = _defaultProvider();

  /// Allows tests to supply a mock or filesystem storage provider.
  static void setStorageProviderForTesting(DatasetStorageProvider provider) {
    _provider = provider;
  }

  /// Resets storage provider to the platform default.
  static void resetStorageProvider() {
    _provider = _defaultProvider();
  }

  // ── Core root operations ──────────────────────────────────────────────────

  /// Launches the system folder picker to select the FRUIT_DATASET folder.
  static Future<PickedDatasetRoot?> pickDatasetRoot() async {
    return _provider.pickDatasetRoot();
  }

  /// Saves [root] as the active dataset root.
  static Future<void> initializeDatasetRoot(PickedDatasetRoot root) async {
    await StorageService.saveDatasetRoot(
      identifier: root.identifier,
      name: root.name,
      isSaf: root.isSaf,
    );
  }

  /// Saves a filesystem path as the active dataset root (used on iOS/Desktop/Tests).
  static Future<void> initializeDatasetRootFromPath(String path) async {
    final name = nameFromPath(path);
    await StorageService.saveDatasetRoot(
      identifier: path,
      name: name,
      isSaf: false,
    );
  }

  /// Returns the stored dataset root identifier (URI or path), or [null] if none is saved.
  static Future<String?> getDatasetRoot() async {
    return StorageService.loadDatasetRootPath();
  }

  /// Returns the stored dataset root display name, or [null].
  static Future<String?> getDatasetRootName() async {
    final name = await StorageService.loadDatasetRootName();
    if (name != null && name.isNotEmpty) return name;
    final path = await getDatasetRoot();
    if (path == null) return null;
    return nameFromPath(path);
  }

  /// Returns [true] if a dataset root is configured AND still accessible by the platform.
  /// If the permission has expired or was revoked, returns [false].
  static Future<bool> hasDatasetRoot() async {
    final rootIdentifier = await StorageService.loadDatasetRootPath();
    if (rootIdentifier == null || rootIdentifier.isEmpty) {
      return false;
    }
    return _provider.hasValidAccess(rootIdentifier);
  }

  /// Clears the saved dataset root so the user can select a new one.
  /// Does NOT touch any files or folders on disk.
  static Future<void> resetDatasetRoot() async {
    await StorageService.clearDatasetRootPath();
  }

  // ── Dataset folder & photo operations ────────────────────────────────────

  /// Ensures that the variety directory is accessible/created under `FRUIT_DATASET/<fruit>/<variety>/`.
  static Future<void> prepareVarietyFolder(String fruit, String variety) async {
    validateSegmentName(fruit, 'Fruit');
    validateSegmentName(variety, 'Variety');

    final root = await getDatasetRoot();
    if (root == null || root.isEmpty) {
      throw StateError(
        'Dataset root folder is not configured. Please select a dataset folder first.',
      );
    }

    await _provider.prepareVarietyFolder(
      rootIdentifier: root,
      fruit: fruit.trim(),
      variety: variety.trim(),
    );
  }

  /// Lists all photo filenames inside `FRUIT_DATASET/<fruit>/<variety>/`.
  static Future<List<String>> listPhotoFilenames(
    String fruit,
    String variety,
  ) async {
    validateSegmentName(fruit, 'Fruit');
    validateSegmentName(variety, 'Variety');

    final root = await getDatasetRoot();
    if (root == null || root.isEmpty) return [];

    return _provider.listPhotoFilenames(
      rootIdentifier: root,
      fruit: fruit.trim(),
      variety: variety.trim(),
    );
  }

  /// Returns a set of all used integer photo indices for `FRUIT_DATASET/<fruit>/<variety>/`.
  static Future<Set<int>> getExistingPhotoIndices(
    String fruit,
    String variety,
  ) async {
    final filenames = await listPhotoFilenames(fruit, variety);
    return FileNamingService.extractIndices(filenames);
  }

  /// Returns the total count of valid `photo_XXX.jpg` files in the selected variety folder.
  static Future<int> countPhotos(String fruit, String variety) async {
    final filenames = await listPhotoFilenames(fruit, variety);
    return FileNamingService.countPhotosFromFilenames(filenames);
  }

  /// Determines the next available sequential photo filename (e.g. `photo_001.jpg`).
  static Future<String> getNextPhotoFilename(
    String fruit,
    String variety,
  ) async {
    final filenames = await listPhotoFilenames(fruit, variety);
    return FileNamingService.calculateNextFilename(filenames);
  }

  /// Saves a captured photo into `FRUIT_DATASET/<fruit>/<variety>/<nextFilename>`.
  /// Uses SAF on Android, or direct filesystem on iOS/Desktop.
  /// Returns the saved URI or path string.
  static Future<String> saveCapturedPhoto({
    required String fruit,
    required String variety,
    required XFile capturedFile,
  }) async {
    validateSegmentName(fruit, 'Fruit');
    validateSegmentName(variety, 'Variety');

    final root = await getDatasetRoot();
    if (root == null || root.isEmpty) {
      throw StateError(
        'Dataset root folder is not configured. Please select a dataset folder first.',
      );
    }

    final hasAccess = await _provider.hasValidAccess(root);
    if (!hasAccess) {
      throw StateError(
        'Dataset folder access expired. Please select FRUIT_DATASET again.',
      );
    }

    // Determine next sequential filename
    final nextFilename = await getNextPhotoFilename(fruit, variety);

    // Read captured JPEG bytes
    final bytes = await capturedFile.readAsBytes();

    // Save image through storage provider
    return _provider.saveImageBytes(
      rootIdentifier: root,
      fruit: fruit.trim(),
      variety: variety.trim(),
      filename: nextFilename,
      bytes: bytes,
    );
  }

  // ── Legacy / Filesystem compatibility helpers ────────────────────────────

  /// Ensures that the fruit directory exists under the dataset root:
  /// `FRUIT_DATASET/<fruit>/`
  ///
  /// Reuses the folder if it already exists. Never recreates or deletes data.
  /// Throws [StateError] if no dataset root is configured.
  /// Throws [ArgumentError] if [fruit] name is invalid or contains path traversal.
  static Future<Directory> getOrCreateFruitFolder(String fruit) async {
    validateSegmentName(fruit, 'Fruit');

    final rootPath = await getDatasetRoot();
    if (rootPath == null || rootPath.isEmpty) {
      throw StateError(
        'Dataset root folder is not configured. Please select a dataset folder first.',
      );
    }

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }

    final fruitDirPath = _combinePath(rootPath, fruit.trim());
    final fruitDir = Directory(fruitDirPath);

    // Guard against directory traversal
    _ensureInsideParent(fruitDir, rootDir);

    if (!await fruitDir.exists()) {
      await fruitDir.create(recursive: true);
    }

    return fruitDir;
  }

  /// Ensures that the variety directory exists under the fruit directory:
  /// `FRUIT_DATASET/<fruit>/<variety>/`
  ///
  /// Reuses the folder if it already exists. Never recreates or deletes data.
  /// Throws [StateError] if no dataset root is configured.
  /// Throws [ArgumentError] if [fruit] or [variety] name is invalid.
  static Future<Directory> getOrCreateVarietyFolder(
    String fruit,
    String variety,
  ) async {
    validateSegmentName(variety, 'Variety');

    final fruitDir = await getOrCreateFruitFolder(fruit);
    final varietyDirPath = _combinePath(fruitDir.path, variety.trim());
    final varietyDir = Directory(varietyDirPath);

    // Guard against directory traversal
    _ensureInsideParent(varietyDir, fruitDir);

    if (!await varietyDir.exists()) {
      await varietyDir.create(recursive: true);
    }

    return varietyDir;
  }

  // ── Name validation & safety ──────────────────────────────────────────────

  /// Disallowed characters in single path segments (Windows & POSIX safe).
  static final RegExp _invalidCharsRegex = RegExp(r'[\/\\:\*\?"<>\|\x00-\x1F]');

  /// Validates that [name] is a safe directory name without path traversal.
  /// Throws [ArgumentError] if invalid.
  static void validateSegmentName(String name, [String fieldName = 'Name']) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('$fieldName cannot be empty.');
    }

    if (trimmed == '.' || trimmed == '..' || trimmed.contains('..')) {
      throw ArgumentError(
        '$fieldName "$name" contains illegal relative path navigation ("..").',
      );
    }

    if (_invalidCharsRegex.hasMatch(trimmed)) {
      throw ArgumentError(
        '$fieldName "$name" contains invalid characters (path separators, colons, wildcards, etc.).',
      );
    }

    if (trimmed.startsWith('.') || trimmed.endsWith('.')) {
      throw ArgumentError(
        '$fieldName "$name" cannot start or end with a period.',
      );
    }
  }

  /// Returns [true] if [name] is a valid fruit or variety segment name.
  static bool isValidSegmentName(String name) {
    try {
      validateSegmentName(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Combines a parent path and a child folder name cleanly.
  static String _combinePath(String parent, String child) {
    final cleanParent = parent.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    return '$cleanParent/$child';
  }

  /// Asserts that [childDir] is strictly inside [parentDir].
  static void _ensureInsideParent(Directory childDir, Directory parentDir) {
    var normalizedChild = childDir.path.replaceAll(r'\', '/').toLowerCase();
    var normalizedParent = parentDir.path.replaceAll(r'\', '/').toLowerCase();

    if (!normalizedParent.endsWith('/')) {
      normalizedParent = '$normalizedParent/';
    }
    if (!normalizedChild.endsWith('/')) {
      normalizedChild = '$normalizedChild/';
    }

    if (!normalizedChild.startsWith(normalizedParent) ||
        normalizedChild == normalizedParent) {
      throw ArgumentError(
        'Path traversal detected: "${childDir.path}" is outside "${parentDir.path}".',
      );
    }
  }

  /// Extracts the last path segment from an absolute path or URI string.
  static String nameFromPath(String pathOrUri) {
    // If it's a URI with query/encoded characters, decode first
    final decoded = Uri.decodeFull(pathOrUri);
    return decoded
        .replaceAll(r'\', '/')
        .split(RegExp(r'[:\/]'))
        .where((s) => s.isNotEmpty)
        .lastOrNull ??
        '';
  }

  /// Returns [true] if the folder at [pathOrName] is named [expectedRootName].
  static bool isValidRootName(String pathOrName) {
    return nameFromPath(pathOrName) == expectedRootName;
  }
}

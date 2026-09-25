import 'package:shared_preferences/shared_preferences.dart';

/// Low-level key/value persistence for the RIPENX app.
/// Stores the dataset root identifier (SAF Document Tree URI on Android, or filesystem path on other platforms).
abstract final class StorageService {
  static const String _keyDatasetRootIdentifier = 'dataset_root_path';
  static const String _keyDatasetRootName = 'dataset_root_name';
  static const String _keyDatasetIsSaf = 'dataset_is_saf';

  // ── Dataset root persistence ─────────────────────────────────────────────

  /// Persists the selected dataset root configuration.
  static Future<void> saveDatasetRoot({
    required String identifier,
    required String name,
    required bool isSaf,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDatasetRootIdentifier, identifier);
    await prefs.setString(_keyDatasetRootName, name);
    await prefs.setBool(_keyDatasetIsSaf, isSaf);
  }

  /// Backwards-compatible path saver.
  static Future<void> saveDatasetRootPath(String path) async {
    final name = path.replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'FRUIT_DATASET';
    await saveDatasetRoot(identifier: path, name: name, isSaf: false);
  }

  /// Returns the previously persisted dataset root identifier (URI or path), or [null].
  static Future<String?> loadDatasetRootPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDatasetRootIdentifier);
  }

  /// Returns the persisted dataset root folder display name, or [null].
  static Future<String?> loadDatasetRootName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDatasetRootName);
  }

  /// Returns whether the stored root identifier is an Android SAF URI.
  static Future<bool> loadDatasetIsSaf() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDatasetIsSaf) ?? false;
  }

  /// Removes the saved dataset root configuration (used when changing folder).
  static Future<void> clearDatasetRootPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDatasetRootIdentifier);
    await prefs.remove(_keyDatasetRootName);
    await prefs.remove(_keyDatasetIsSaf);
  }
}

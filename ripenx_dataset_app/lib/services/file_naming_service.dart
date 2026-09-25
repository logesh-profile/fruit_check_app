import 'dart:io';

/// Handles sequential photo naming and numbering for dataset collection.
///
/// Format: `photo_001.jpg`, `photo_002.jpg`, `photo_003.jpg`, etc.
/// Numbering starts at 1 and fills the lowest available positive integer gap.
/// Existing files are never overwritten.
abstract final class FileNamingService {
  /// Regular expression matching valid dataset photo filenames (e.g., photo_001.jpg, photo_042.jpg).
  static final RegExp photoPattern = RegExp(r'^photo_(\d{3,})\.jpg$', caseSensitive: false);

  /// Formats an integer index into the standard photo filename.
  /// Example: 1 -> 'photo_001.jpg', 42 -> 'photo_042.jpg', 100 -> 'photo_100.jpg'.
  static String formatFilename(int index) {
    if (index < 1) {
      throw ArgumentError('Photo index must be positive (>= 1). Got $index');
    }
    final padded = index.toString().padLeft(3, '0');
    return 'photo_$padded.jpg';
  }

  /// Extracts the integer index from a filename if it matches `photo_XXX.jpg`, or returns [null].
  static int? extractIndex(String filename) {
    final match = photoPattern.firstMatch(filename);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Extracts indices from a collection of filenames.
  static Set<int> extractIndices(Iterable<String> filenames) {
    final indices = <int>{};
    for (final name in filenames) {
      final idx = extractIndex(name);
      if (idx != null && idx > 0) {
        indices.add(idx);
      }
    }
    return indices;
  }

  /// Calculates the next available photo filename from a list of [existingFilenames].
  /// Fills the lowest available integer gap starting from 1.
  static String calculateNextFilename(Iterable<String> existingFilenames) {
    final usedIndices = extractIndices(existingFilenames);
    var candidateIndex = 1;
    while (usedIndices.contains(candidateIndex)) {
      candidateIndex++;
    }
    return formatFilename(candidateIndex);
  }

  /// Counts the total number of valid `photo_XXX.jpg` files from [existingFilenames].
  static int countPhotosFromFilenames(Iterable<String> existingFilenames) {
    return extractIndices(existingFilenames).length;
  }

  // ── Filesystem Directory Helpers (used for backward compatibility / tests) ──

  /// Returns the next available photo filename for [directory] (e.g., `photo_001.jpg`).
  static Future<String> getNextPhotoFilename(Directory directory) async {
    final usedIndices = await getExistingPhotoIndices(directory);

    var candidateIndex = 1;
    while (usedIndices.contains(candidateIndex)) {
      candidateIndex++;
    }

    var candidateFilename = formatFilename(candidateIndex);

    // Safety check against race conditions or unlisted files
    while (await File('${directory.path}/$candidateFilename').exists()) {
      candidateIndex++;
      candidateFilename = formatFilename(candidateIndex);
    }

    return candidateFilename;
  }

  /// Returns the full file path for the next available photo in [directory].
  static Future<String> getNextPhotoPath(Directory directory) async {
    final filename = await getNextPhotoFilename(directory);
    final cleanDirPath = directory.path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    return '$cleanDirPath/$filename';
  }

  /// Returns a set of all used photo indices currently present in [directory].
  static Future<Set<int>> getExistingPhotoIndices(Directory directory) async {
    final filenames = <String>[];
    if (!await directory.exists()) {
      return {};
    }

    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File) {
          final basename = entity.path
              .replaceAll(r'\', '/')
              .split('/')
              .where((s) => s.isNotEmpty)
              .last;
          filenames.add(basename);
        }
      }
    } catch (_) {
      // Return whatever was collected safely
    }

    return extractIndices(filenames);
  }

  /// Returns the total number of valid `photo_XXX.jpg` files in [directory].
  static Future<int> countPhotos(Directory directory) async {
    final indices = await getExistingPhotoIndices(directory);
    return indices.length;
  }
}

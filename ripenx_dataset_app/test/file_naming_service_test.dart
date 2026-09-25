import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ripenx_dataset_app/services/file_naming_service.dart';

void main() {
  group('FileNamingService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ripenx_naming_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Empty directory yields photo_001.jpg', () async {
      final nextName = await FileNamingService.getNextPhotoFilename(tempDir);
      expect(nextName, equals('photo_001.jpg'));

      final nextPath = await FileNamingService.getNextPhotoPath(tempDir);
      expect(nextPath.replaceAll(r'\', '/'), endsWith('/photo_001.jpg'));
      expect(await FileNamingService.countPhotos(tempDir), equals(0));
    });

    test('2. photo_001.jpg exists yields photo_002.jpg', () async {
      await File('${tempDir.path}/photo_001.jpg').writeAsString('test');

      final nextName = await FileNamingService.getNextPhotoFilename(tempDir);
      expect(nextName, equals('photo_002.jpg'));
      expect(await FileNamingService.countPhotos(tempDir), equals(1));
    });

    test('3. photo_001.jpg through photo_005.jpg exist yields photo_006.jpg', () async {
      for (int i = 1; i <= 5; i++) {
        final filename = FileNamingService.formatFilename(i);
        await File('${tempDir.path}/$filename').writeAsString('test $i');
      }

      final nextName = await FileNamingService.getNextPhotoFilename(tempDir);
      expect(nextName, equals('photo_006.jpg'));
      expect(await FileNamingService.countPhotos(tempDir), equals(5));
    });

    test('4. photo_001.jpg and photo_003.jpg exist yields photo_002.jpg (gap filling)', () async {
      await File('${tempDir.path}/photo_001.jpg').writeAsString('test 1');
      await File('${tempDir.path}/photo_003.jpg').writeAsString('test 3');

      final nextName = await FileNamingService.getNextPhotoFilename(tempDir);
      expect(nextName, equals('photo_002.jpg'));
      expect(await FileNamingService.countPhotos(tempDir), equals(2));
    });

    test('5. Existing files are never overwritten (safety increment)', () async {
      final nextPath = await FileNamingService.getNextPhotoPath(tempDir);
      // Create candidate file directly before next call
      await File(nextPath).writeAsString('original data');

      final afterCreated = await FileNamingService.getNextPhotoPath(tempDir);
      expect(afterCreated, isNot(equals(nextPath)));
      expect(afterCreated.replaceAll(r'\', '/'), endsWith('/photo_002.jpg'));
      // Original data intact
      expect(await File(nextPath).readAsString(), equals('original data'));
    });

    test('6. Non-photo files should not break numbering', () async {
      await File('${tempDir.path}/notes.txt').writeAsString('some notes');
      await File('${tempDir.path}/photo_001.png').writeAsString('png image');
      await File('${tempDir.path}/IMG_002.jpg').writeAsString('camera image');
      await File('${tempDir.path}/photo_invalid.jpg').writeAsString('invalid');

      // None of the above are valid photo_XXX.jpg files
      expect(await FileNamingService.countPhotos(tempDir), equals(0));
      final nextName = await FileNamingService.getNextPhotoFilename(tempDir);
      expect(nextName, equals('photo_001.jpg'));

      // Add a valid photo
      await File('${tempDir.path}/photo_001.jpg').writeAsString('photo');
      expect(await FileNamingService.countPhotos(tempDir), equals(1));
      expect(await FileNamingService.getNextPhotoFilename(tempDir), equals('photo_002.jpg'));
    });

    test('formatFilename formats indices correctly', () {
      expect(FileNamingService.formatFilename(1), 'photo_001.jpg');
      expect(FileNamingService.formatFilename(9), 'photo_009.jpg');
      expect(FileNamingService.formatFilename(10), 'photo_010.jpg');
      expect(FileNamingService.formatFilename(99), 'photo_099.jpg');
      expect(FileNamingService.formatFilename(100), 'photo_100.jpg');
      expect(FileNamingService.formatFilename(999), 'photo_999.jpg');
      expect(FileNamingService.formatFilename(1000), 'photo_1000.jpg');
      expect(() => FileNamingService.formatFilename(0), throwsArgumentError);
      expect(() => FileNamingService.formatFilename(-5), throwsArgumentError);
    });

    test('extractIndex parses valid filenames and ignores invalid ones', () {
      expect(FileNamingService.extractIndex('photo_001.jpg'), 1);
      expect(FileNamingService.extractIndex('PHOTO_042.JPG'), 42);
      expect(FileNamingService.extractIndex('photo_100.jpg'), 100);
      expect(FileNamingService.extractIndex('photo_1.jpg'), isNull); // not 3 digits
      expect(FileNamingService.extractIndex('photo_01.jpg'), isNull); // not 3 digits
      expect(FileNamingService.extractIndex('img_001.jpg'), isNull);
      expect(FileNamingService.extractIndex('photo_001.png'), isNull);
    });
  });
}

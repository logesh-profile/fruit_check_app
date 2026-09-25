import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ripenx_dataset_app/services/dataset_service.dart';
import 'package:ripenx_dataset_app/services/image_storage_service.dart';
import 'package:ripenx_dataset_app/services/storage_provider.dart';

void main() {
  group('ImageStorageService & Dataset Hierarchy Integration', () {
    late Directory tempRootDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      DatasetService.setStorageProviderForTesting(FileSystemStorageProvider());
      tempRootDir = await Directory.systemTemp.createTemp('ripenx_storage_test_');
      await DatasetService.initializeDatasetRootFromPath(tempRootDir.path);
    });

    tearDown(() async {
      DatasetService.resetStorageProvider();
      try {
        if (await tempRootDir.exists()) {
          await tempRootDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('7. Correct destination is FRUIT_DATASET/Mango/Totapuri/photo_001.jpg', () async {
      // Create a dummy captured photo
      final tempCaptureFile = File('${tempRootDir.path}/temp_capture_1.jpg');
      await tempCaptureFile.writeAsBytes([1, 2, 3, 4, 5]);

      final savedResult = await ImageStorageService.saveCapturedImage(
        capturedFile: XFile(tempCaptureFile.path),
        fruit: 'Mango',
        variety: 'Totapuri',
      );

      final savedFile = File(savedResult);
      expect(await savedFile.exists(), isTrue);
      expect(
        savedFile.path.replaceAll(r'\', '/'),
        endsWith('/Mango/Totapuri/photo_001.jpg'),
      );
      expect(await savedFile.readAsBytes(), equals([1, 2, 3, 4, 5]));
      expect(await DatasetService.countPhotos('Mango', 'Totapuri'), equals(1));

      // Capture a second photo in the same variety
      final tempCaptureFile2 = File('${tempRootDir.path}/temp_capture_2.jpg');
      await tempCaptureFile2.writeAsBytes([6, 7, 8, 9]);

      final savedResult2 = await ImageStorageService.saveCapturedImage(
        capturedFile: XFile(tempCaptureFile2.path),
        fruit: 'Mango',
        variety: 'Totapuri',
      );

      final savedFile2 = File(savedResult2);
      expect(await savedFile2.exists(), isTrue);
      expect(
        savedFile2.path.replaceAll(r'\', '/'),
        endsWith('/Mango/Totapuri/photo_002.jpg'),
      );
      expect(await savedFile2.readAsBytes(), equals([6, 7, 8, 9]));
      expect(await DatasetService.countPhotos('Mango', 'Totapuri'), equals(2));
    });

    test('8. Different variety uses a different directory', () async {
      final tempCapture1 = File('${tempRootDir.path}/temp_1.jpg');
      await tempCapture1.writeAsBytes([10, 20]);
      final savedTotapuri = await ImageStorageService.saveCapturedImage(
        capturedFile: XFile(tempCapture1.path),
        fruit: 'Mango',
        variety: 'Totapuri',
      );

      final tempCapture2 = File('${tempRootDir.path}/temp_2.jpg');
      await tempCapture2.writeAsBytes([30, 40]);
      final savedBanganapalli = await ImageStorageService.saveCapturedImage(
        capturedFile: XFile(tempCapture2.path),
        fruit: 'Mango',
        variety: 'Banganapalli',
      );

      expect(savedTotapuri.replaceAll(r'\', '/'), endsWith('/Mango/Totapuri/photo_001.jpg'));
      expect(savedBanganapalli.replaceAll(r'\', '/'), endsWith('/Mango/Banganapalli/photo_001.jpg'));
      expect(await DatasetService.countPhotos('Mango', 'Totapuri'), equals(1));
      expect(await DatasetService.countPhotos('Mango', 'Banganapalli'), equals(1));
    });

    test('9. Different fruit uses a different directory', () async {
      final tempCapture1 = File('${tempRootDir.path}/temp_m.jpg');
      await tempCapture1.writeAsBytes([100]);
      final savedMango = await ImageStorageService.saveCapturedImage(
        capturedFile: XFile(tempCapture1.path),
        fruit: 'Mango',
        variety: 'Totapuri',
      );

      final tempCapture2 = File('${tempRootDir.path}/temp_b.jpg');
      await tempCapture2.writeAsBytes([200]);
      final savedBanana = await ImageStorageService.saveCapturedImage(
        capturedFile: XFile(tempCapture2.path),
        fruit: 'Banana',
        variety: 'Robusta',
      );

      expect(savedMango.replaceAll(r'\', '/'), endsWith('/Mango/Totapuri/photo_001.jpg'));
      expect(savedBanana.replaceAll(r'\', '/'), endsWith('/Banana/Robusta/photo_001.jpg'));
      expect(await DatasetService.countPhotos('Mango', 'Totapuri'), equals(1));
      expect(await DatasetService.countPhotos('Banana', 'Robusta'), equals(1));
    });
  });
}

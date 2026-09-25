import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ripenx_dataset_app/services/dataset_service.dart';
import 'package:ripenx_dataset_app/services/storage_provider.dart';

/// In-memory fake storage provider for testing SAF-like tree operations without filesystem dependencies.
class FakeDocumentTreeStorageProvider implements DatasetStorageProvider {
  FakeDocumentTreeStorageProvider({this.hasAccess = true});

  bool hasAccess;
  final Map<String, Uint8List> storage = {};
  final Set<String> createdDirectories = {};

  @override
  Future<PickedDatasetRoot?> pickDatasetRoot() async {
    return const PickedDatasetRoot(
      identifier: 'content://com.android.externalstorage.documents/tree/primary%3AFRUIT_DATASET',
      name: 'FRUIT_DATASET',
      isSaf: true,
    );
  }

  @override
  Future<bool> hasValidAccess(String rootIdentifier) async {
    return hasAccess;
  }

  @override
  Future<List<String>> listPhotoFilenames({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {
    final prefix = '$rootIdentifier/$fruit/$variety/';
    final filenames = <String>[];
    for (final key in storage.keys) {
      if (key.startsWith(prefix)) {
        filenames.add(key.substring(prefix.length));
      }
    }
    return filenames;
  }

  @override
  Future<String> saveImageBytes({
    required String rootIdentifier,
    required String fruit,
    required String variety,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (!hasAccess) {
      throw StateError('Dataset folder access expired.');
    }
    // Record variety directory creation
    createdDirectories.add('$rootIdentifier/$fruit/$variety');

    final key = '$rootIdentifier/$fruit/$variety/$filename';
    if (storage.containsKey(key)) {
      throw StateError('File "$key" already exists.');
    }
    storage[key] = bytes;
    return key;
  }

  @override
  Future<void> prepareVarietyFolder({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {
    if (!hasAccess) {
      throw StateError('Dataset folder access expired.');
    }
    createdDirectories.add('$rootIdentifier/$fruit/$variety');
  }
}

void main() {
  group('Fake Document Tree Provider Tests (Simulating Android SAF)', () {
    late FakeDocumentTreeStorageProvider fakeProvider;
    const testUri = 'content://com.android.externalstorage.documents/tree/primary%3AFRUIT_DATASET';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fakeProvider = FakeDocumentTreeStorageProvider();
      DatasetService.setStorageProviderForTesting(fakeProvider);
      await DatasetService.initializeDatasetRoot(
        const PickedDatasetRoot(
          identifier: testUri,
          name: 'FRUIT_DATASET',
          isSaf: true,
        ),
      );
    });

    tearDown(() {
      DatasetService.resetStorageProvider();
    });

    test('1. Selecting Mango + Totapuri creates Mango/Totapuri and saves only in Mango/Totapuri (Root contains NO JPEG)', () async {
      await DatasetService.prepareVarietyFolder('Mango', 'Totapuri');
      expect(
        fakeProvider.createdDirectories,
        contains('$testUri/Mango/Totapuri'),
      );

      final dummyFile = XFile.fromData(Uint8List.fromList([1, 2, 3, 4]));
      final savedPath = await DatasetService.saveCapturedPhoto(
        fruit: 'Mango',
        variety: 'Totapuri',
        capturedFile: dummyFile,
      );

      expect(savedPath, equals('$testUri/Mango/Totapuri/photo_001.jpg'));
      expect(fakeProvider.storage.containsKey('$testUri/Mango/Totapuri/photo_001.jpg'), isTrue);

      // Verify that the root FRUIT_DATASET contains NO captured JPEG
      for (final key in fakeProvider.storage.keys) {
        expect(key.startsWith('$testUri/Mango/Totapuri/'), isTrue);
        expect(key, isNot(equals('$testUri/photo_001.jpg')));
      }
    });

    test('2. Multi-variety and multi-fruit isolation', () async {
      final dummyFile1 = XFile.fromData(Uint8List.fromList([10, 20]));
      final dummyFile2 = XFile.fromData(Uint8List.fromList([30, 40]));
      final dummyFile3 = XFile.fromData(Uint8List.fromList([50, 60]));

      // Save Mango/Totapuri
      await DatasetService.saveCapturedPhoto(
        fruit: 'Mango',
        variety: 'Totapuri',
        capturedFile: dummyFile1,
      );

      // Save Mango/Banganapalli
      await DatasetService.saveCapturedPhoto(
        fruit: 'Mango',
        variety: 'Banganapalli',
        capturedFile: dummyFile2,
      );

      // Save Banana/Robusta
      await DatasetService.saveCapturedPhoto(
        fruit: 'Banana',
        variety: 'Robusta',
        capturedFile: dummyFile3,
      );

      // Verify Mango/Totapuri has only 1 photo
      expect(await DatasetService.countPhotos('Mango', 'Totapuri'), equals(1));
      expect(fakeProvider.storage.containsKey('$testUri/Mango/Totapuri/photo_001.jpg'), isTrue);

      // Verify Mango/Banganapalli has only 1 photo
      expect(await DatasetService.countPhotos('Mango', 'Banganapalli'), equals(1));
      expect(fakeProvider.storage.containsKey('$testUri/Mango/Banganapalli/photo_001.jpg'), isTrue);

      // Verify Banana/Robusta has only 1 photo
      expect(await DatasetService.countPhotos('Banana', 'Robusta'), equals(1));
      expect(fakeProvider.storage.containsKey('$testUri/Banana/Robusta/photo_001.jpg'), isTrue);
    });

    test('3. Sequential filename generation and image persistence on Document Tree', () async {
      final dummyFile = XFile.fromData(Uint8List.fromList([1, 2, 3, 4]));

      // Save photo 1
      await DatasetService.saveCapturedPhoto(
        fruit: 'Mango',
        variety: 'Banganapalli',
        capturedFile: dummyFile,
      );

      expect(await DatasetService.countPhotos('Mango', 'Banganapalli'), equals(1));
      expect(
        await DatasetService.getNextPhotoFilename('Mango', 'Banganapalli'),
        equals('photo_002.jpg'),
      );

      // Save photo 2
      await DatasetService.saveCapturedPhoto(
        fruit: 'Mango',
        variety: 'Banganapalli',
        capturedFile: dummyFile,
      );

      expect(await DatasetService.countPhotos('Mango', 'Banganapalli'), equals(2));
      expect(
        await DatasetService.getNextPhotoFilename('Mango', 'Banganapalli'),
        equals('photo_003.jpg'),
      );
    });

    test('4. Gap-filling filename generation (e.g. photo_001 and photo_003 -> photo_002)', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3]);

      await fakeProvider.saveImageBytes(
        rootIdentifier: testUri,
        fruit: 'Mango',
        variety: 'Banganapalli',
        filename: 'photo_001.jpg',
        bytes: dummyBytes,
      );

      await fakeProvider.saveImageBytes(
        rootIdentifier: testUri,
        fruit: 'Mango',
        variety: 'Banganapalli',
        filename: 'photo_003.jpg',
        bytes: dummyBytes,
      );

      expect(
        await DatasetService.getNextPhotoFilename('Mango', 'Banganapalli'),
        equals('photo_002.jpg'),
      );
      expect(await DatasetService.countPhotos('Mango', 'Banganapalli'), equals(2));
    });

    test('5. No overwrite rule - duplicate save is prevented', () async {
      final dummyBytes = Uint8List.fromList([10, 20]);

      await fakeProvider.saveImageBytes(
        rootIdentifier: testUri,
        fruit: 'Mango',
        variety: 'Banganapalli',
        filename: 'photo_001.jpg',
        bytes: dummyBytes,
      );

      expect(
        () => fakeProvider.saveImageBytes(
          rootIdentifier: testUri,
          fruit: 'Mango',
          variety: 'Banganapalli',
          filename: 'photo_001.jpg',
          bytes: dummyBytes,
        ),
        throwsStateError,
      );
    });

    test('6. Revoked / expired SAF permission is detected and prevents saving', () async {
      fakeProvider.hasAccess = false;

      expect(await DatasetService.hasDatasetRoot(), isFalse);

      final dummyFile = XFile.fromData(Uint8List.fromList([1, 2, 3]));
      expect(
        () => DatasetService.saveCapturedPhoto(
          fruit: 'Mango',
          variety: 'Totapuri',
          capturedFile: dummyFile,
        ),
        throwsStateError,
      );
    });

    test('7. Non-photo files in Document Tree are ignored', () async {
      final dummyBytes = Uint8List.fromList([1, 2]);

      fakeProvider.storage['$testUri/Mango/Totapuri/notes.txt'] = dummyBytes;
      fakeProvider.storage['$testUri/Mango/Totapuri/image.png'] = dummyBytes;
      fakeProvider.storage['$testUri/Mango/Totapuri/IMG_001.jpg'] = dummyBytes;
      fakeProvider.storage['$testUri/Mango/Totapuri/photo_1.jpg'] = dummyBytes;

      expect(await DatasetService.countPhotos('Mango', 'Totapuri'), equals(0));
      expect(
        await DatasetService.getNextPhotoFilename('Mango', 'Totapuri'),
        equals('photo_001.jpg'),
      );
    });
  });
}

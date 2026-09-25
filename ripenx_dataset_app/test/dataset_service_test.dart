import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ripenx_dataset_app/services/dataset_service.dart';
import 'package:ripenx_dataset_app/services/storage_provider.dart';
import 'package:ripenx_dataset_app/services/storage_service.dart';

void main() {
  group('DatasetService & StorageService Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DatasetService.setStorageProviderForTesting(FileSystemStorageProvider());
    });

    tearDown(() {
      DatasetService.resetStorageProvider();
    });

    test('initial state has no dataset root', () async {
      expect(await DatasetService.hasDatasetRoot(), isFalse);
      expect(await DatasetService.getDatasetRoot(), isNull);
      expect(await DatasetService.getDatasetRootName(), isNull);
    });

    test('saving root persists across service calls', () async {
      final tempDir = await Directory.systemTemp.createTemp('FRUIT_DATASET_');
      addTearDown(() => tempDir.delete(recursive: true));

      await DatasetService.initializeDatasetRoot(
        PickedDatasetRoot(
          identifier: tempDir.path,
          name: 'FRUIT_DATASET',
          isSaf: false,
        ),
      );

      expect(await DatasetService.hasDatasetRoot(), isTrue);
      expect(await DatasetService.getDatasetRoot(), equals(tempDir.path));
      expect(await DatasetService.getDatasetRootName(), equals('FRUIT_DATASET'));
    });

    test('simulated app restart preserves saved dataset reference', () async {
      final tempDir = await Directory.systemTemp.createTemp('FRUIT_DATASET_');
      addTearDown(() => tempDir.delete(recursive: true));

      // Step 1: User saves folder
      await DatasetService.initializeDatasetRoot(
        PickedDatasetRoot(
          identifier: tempDir.path,
          name: 'FRUIT_DATASET',
          isSaf: false,
        ),
      );

      // Step 2: App process restarts (simulate by reading afresh from preferences)
      final reloadedPath = await StorageService.loadDatasetRootPath();
      expect(reloadedPath, equals(tempDir.path));

      // Step 3: DatasetService verifies root is ready without re-prompting
      expect(await DatasetService.hasDatasetRoot(), isTrue);
      expect(await DatasetService.getDatasetRoot(), equals(tempDir.path));
      expect(await DatasetService.getDatasetRootName(), equals('FRUIT_DATASET'));
    });

    test('resetting dataset root clears the stored path', () async {
      final tempDir = await Directory.systemTemp.createTemp('FRUIT_DATASET_');
      addTearDown(() => tempDir.delete(recursive: true));

      await DatasetService.initializeDatasetRootFromPath(tempDir.path);
      expect(await DatasetService.hasDatasetRoot(), isTrue);

      await DatasetService.resetDatasetRoot();
      expect(await DatasetService.hasDatasetRoot(), isFalse);
      expect(await DatasetService.getDatasetRoot(), isNull);
    });

    test('revoked or missing folder access is detected instead of falsely reporting success', () async {
      // Set a non-existent path in preferences
      await StorageService.saveDatasetRoot(
        identifier: '/non/existent/folder/FRUIT_DATASET',
        name: 'FRUIT_DATASET',
        isSaf: false,
      );

      // hasDatasetRoot must actively verify access and return false
      expect(await DatasetService.hasDatasetRoot(), isFalse);
    });

    test('nameFromPath parses Unix and Windows separators and URIs correctly', () {
      expect(DatasetService.nameFromPath('/a/b/c/FRUIT_DATASET'), 'FRUIT_DATASET');
      expect(DatasetService.nameFromPath('C:\\Users\\User\\FRUIT_DATASET'), 'FRUIT_DATASET');
      expect(DatasetService.nameFromPath('/FRUIT_DATASET/'), 'FRUIT_DATASET');
      expect(DatasetService.nameFromPath('D:\\FRUIT_DATASET\\'), 'FRUIT_DATASET');
      expect(
        DatasetService.nameFromPath('content://com.android.externalstorage.documents/tree/primary%3AFRUIT_DATASET'),
        'FRUIT_DATASET',
      );
    });

    test('isValidRootName enforces exact FRUIT_DATASET matching', () {
      expect(DatasetService.isValidRootName('/storage/FRUIT_DATASET'), isTrue);
      expect(DatasetService.isValidRootName('C:\\FRUIT_DATASET'), isTrue);
      expect(DatasetService.isValidRootName('FRUIT_DATASET'), isTrue);
      expect(DatasetService.isValidRootName('/storage/fruit_dataset'), isFalse);
      expect(DatasetService.isValidRootName('/storage/FRUIT_DATASETS'), isFalse);
      expect(DatasetService.isValidRootName('/storage/MyImages'), isFalse);
      expect(DatasetService.isValidRootName('DATASET'), isFalse);
    });
  });

  group('Dataset Folder Hierarchy & Creation', () {
    late Directory tempRootDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      DatasetService.setStorageProviderForTesting(FileSystemStorageProvider());
      tempRootDir = await Directory.systemTemp.createTemp('ripenx_test_FRUIT_DATASET_');
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

    test('1. Root is available', () async {
      expect(await DatasetService.hasDatasetRoot(), isTrue);
      expect(await DatasetService.getDatasetRoot(), equals(tempRootDir.path));
    });

    test('2. Fruit folder is created: FRUIT_DATASET/Mango/', () async {
      final fruitDir = await DatasetService.getOrCreateFruitFolder('Mango');
      expect(await fruitDir.exists(), isTrue);
      expect(fruitDir.path.replaceAll(r'\', '/'), endsWith('/Mango'));
    });

    test('3. Variety folder is created: FRUIT_DATASET/Mango/Totapuri/', () async {
      final varietyDir = await DatasetService.getOrCreateVarietyFolder('Mango', 'Totapuri');
      expect(await varietyDir.exists(), isTrue);
      expect(
        varietyDir.path.replaceAll(r'\', '/'),
        endsWith('/Mango/Totapuri'),
      );
    });

    test('4. Calling the same method twice reuses the same directory without error', () async {
      final firstCall = await DatasetService.getOrCreateVarietyFolder('Mango', 'Totapuri');
      expect(await firstCall.exists(), isTrue);

      final secondCall = await DatasetService.getOrCreateVarietyFolder('Mango', 'Totapuri');
      expect(await secondCall.exists(), isTrue);
      expect(secondCall.path, equals(firstCall.path));
    });

    test('5. Different variety creates a different directory: FRUIT_DATASET/Mango/Banganapalli/', () async {
      final totapuri = await DatasetService.getOrCreateVarietyFolder('Mango', 'Totapuri');
      final banganapalli = await DatasetService.getOrCreateVarietyFolder('Mango', 'Banganapalli');

      expect(await totapuri.exists(), isTrue);
      expect(await banganapalli.exists(), isTrue);
      expect(totapuri.path, isNot(equals(banganapalli.path)));
      expect(banganapalli.path.replaceAll(r'\', '/'), endsWith('/Mango/Banganapalli'));
    });

    test('6. Different fruit creates: FRUIT_DATASET/Banana/Robusta/', () async {
      final bananaRobusta = await DatasetService.getOrCreateVarietyFolder('Banana', 'Robusta');
      expect(await bananaRobusta.exists(), isTrue);
      expect(bananaRobusta.path.replaceAll(r'\', '/'), endsWith('/Banana/Robusta'));
    });

    test('7. Path traversal attempts are rejected', () async {
      expect(
        () => DatasetService.getOrCreateFruitFolder('../Mango'),
        throwsArgumentError,
      );
      expect(
        () => DatasetService.getOrCreateFruitFolder('../../something'),
        throwsArgumentError,
      );
      expect(
        () => DatasetService.getOrCreateFruitFolder('Mango/Other'),
        throwsArgumentError,
      );
      expect(
        () => DatasetService.getOrCreateVarietyFolder('Mango', 'Totapuri/subfolder'),
        throwsArgumentError,
      );
      expect(
        () => DatasetService.getOrCreateVarietyFolder('Mango', '..'),
        throwsArgumentError,
      );
    });

    test('8. Empty fruit or variety names are rejected', () async {
      expect(
        () => DatasetService.getOrCreateFruitFolder(''),
        throwsArgumentError,
      );
      expect(
        () => DatasetService.getOrCreateFruitFolder('   '),
        throwsArgumentError,
      );
      expect(
        () => DatasetService.getOrCreateVarietyFolder('Mango', ''),
        throwsArgumentError,
      );
      expect(
        () => DatasetService.getOrCreateVarietyFolder('Mango', '   '),
        throwsArgumentError,
      );
    });

    test('9. Attempting folder creation without root configured throws StateError', () async {
      await DatasetService.resetDatasetRoot();
      expect(
        () => DatasetService.getOrCreateFruitFolder('Mango'),
        throwsStateError,
      );
    });
  });
}

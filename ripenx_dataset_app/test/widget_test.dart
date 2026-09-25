import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ripenx_dataset_app/main.dart';
import 'package:ripenx_dataset_app/screens/variety_screen.dart';
import 'package:ripenx_dataset_app/services/dataset_service.dart';
import 'package:ripenx_dataset_app/services/storage_provider.dart';

class _FakeProvider implements DatasetStorageProvider {
  @override
  Future<PickedDatasetRoot?> pickDatasetRoot() async => const PickedDatasetRoot(
        identifier: 'mock_root',
        name: 'FRUIT_DATASET',
        isSaf: true,
      );

  @override
  Future<bool> hasValidAccess(String rootIdentifier) async => true;

  @override
  Future<List<String>> listPhotoFilenames({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async =>
      [];

  @override
  Future<String> saveImageBytes({
    required String rootIdentifier,
    required String fruit,
    required String variety,
    required String filename,
    required dynamic bytes,
  }) async =>
      '$rootIdentifier/$fruit/$variety/$filename';

  @override
  Future<void> prepareVarietyFolder({
    required String rootIdentifier,
    required String fruit,
    required String variety,
  }) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatasetService.setStorageProviderForTesting(_FakeProvider());
  });

  tearDown(() {
    DatasetService.resetStorageProvider();
  });

  testWidgets(
    'Fresh launch shows DatasetSetupScreen',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const RipenxApp());
      await tester.pumpAndSettle();

      expect(find.text('Dataset Setup'), findsOneWidget);
      expect(find.text('Select FRUIT_DATASET Folder'), findsOneWidget);
    },
  );

  testWidgets(
    'Saved dataset root shows HomeScreen',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(
        {
          'dataset_root_path': 'mock_root',
          'dataset_root_name': 'FRUIT_DATASET',
          'dataset_is_saf': true,
        },
      );
      await tester.pumpWidget(const RipenxApp());
      await tester.pumpAndSettle();

      expect(find.text('RIPENX'), findsOneWidget);
      expect(find.text('Fruit Dataset Collection'), findsOneWidget);
      expect(find.text('Start Collection'), findsOneWidget);
    },
  );

  testWidgets(
    'HomeScreen shows FRUIT_DATASET badge when root is saved',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(
        {
          'dataset_root_path': 'mock_root',
          'dataset_root_name': 'FRUIT_DATASET',
          'dataset_is_saf': true,
        },
      );
      await tester.pumpWidget(const RipenxApp());
      await tester.pumpAndSettle();

      expect(find.text('FRUIT_DATASET'), findsOneWidget);
    },
  );

  testWidgets(
    'Variety selection prepares folder and navigates to CameraScreen',
    (WidgetTester tester) async {
      final tempDir = Directory.systemTemp.createTempSync('ripenx_widget_FRUIT_DATASET_');
      addTearDown(() {
        try {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await DatasetService.initializeDatasetRootFromPath(tempDir.path);

      await tester.pumpWidget(
        const MaterialApp(
          home: VarietyScreen(fruit: 'Mango'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Totapuri variety
      expect(find.text('Totapuri'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Totapuri'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // On CameraScreen
      expect(find.text('Photos captured: 0'), findsOneWidget);
    },
  );
}

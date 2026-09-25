import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ripenx_dataset_app/services/storage_service.dart';

void main() {
  group('Custom Fruits & Varieties Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Initial custom fruits list is empty', () async {
      final fruits = await StorageService.loadCustomFruits();
      expect(fruits, isEmpty);
    });

    test('2. Custom fruits are saved and persisted across app restarts', () async {
      await StorageService.saveCustomFruits(['Guava', 'Pineapple']);

      final loaded = await StorageService.loadCustomFruits();
      expect(loaded, equals(['Guava', 'Pineapple']));
    });

    test('3. Custom varieties are saved and persisted per fruit', () async {
      // Save varieties for Guava
      await StorageService.saveCustomVarieties('Guava', ['Allahabad Safeda', 'Lucknow 49']);
      // Save varieties for Mango
      await StorageService.saveCustomVarieties('Mango', ['Neelum']);

      final guavaVarieties = await StorageService.loadCustomVarieties('Guava');
      expect(guavaVarieties, equals(['Allahabad Safeda', 'Lucknow 49']));

      final mangoVarieties = await StorageService.loadCustomVarieties('Mango');
      expect(mangoVarieties, equals(['Neelum']));

      // Other fruit has empty custom varieties
      final bananaVarieties = await StorageService.loadCustomVarieties('Banana');
      expect(bananaVarieties, isEmpty);
    });

    test('4. Custom variety retrieval is case-insensitive for fruit name', () async {
      await StorageService.saveCustomVarieties('Guava', ['Allahabad Safeda']);

      final loadedLower = await StorageService.loadCustomVarieties('guava');
      final loadedUpper = await StorageService.loadCustomVarieties('GUAVA');

      expect(loadedLower, equals(['Allahabad Safeda']));
      expect(loadedUpper, equals(['Allahabad Safeda']));
    });
  });
}

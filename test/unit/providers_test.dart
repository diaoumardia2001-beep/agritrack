// test/unit/providers_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/locale_provider.dart';
import 'package:agritrack/providers/theme_provider.dart';

void main() {
  group('Providers Unit Tests', () {
    test('ThemeModeNotifier toggles between light and dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('LocaleNotifier switches between French and English', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(localeProvider).languageCode, 'fr');

      container.read(localeProvider.notifier).toggleLocale();
      expect(container.read(localeProvider).languageCode, 'en');

      container.read(localeProvider.notifier).setLocale(const Locale('fr', 'CI'));
      expect(container.read(localeProvider).languageCode, 'fr');
      expect(container.read(localeProvider).countryCode, 'CI');
    });

    test('AnimalFilter initial state and copyWith', () {
      const filter = AnimalFilter();
      expect(filter.searchQuery, '');
      expect(filter.selectedType, isNull);

      final updated = filter.copyWith(
        searchQuery: 'Moussa',
        selectedType: AnimalType.bovin,
      );
      expect(updated.searchQuery, 'Moussa');
      expect(updated.selectedType, AnimalType.bovin);

      final cleared = updated.copyWith(clearType: true);
      expect(cleared.searchQuery, 'Moussa');
      expect(cleared.selectedType, isNull);
    });

    test('AnimalFilterNotifier updates search query and type', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(animalFilterProvider).searchQuery, '');
      expect(container.read(animalFilterProvider).selectedType, isNull);

      container.read(animalFilterProvider.notifier).setSearchQuery('Bakary');
      expect(container.read(animalFilterProvider).searchQuery, 'Bakary');

      container.read(animalFilterProvider.notifier).setType(AnimalType.caprin);
      expect(container.read(animalFilterProvider).selectedType, AnimalType.caprin);

      // Toggling same type unselects it
      container.read(animalFilterProvider.notifier).setType(AnimalType.caprin);
      expect(container.read(animalFilterProvider).selectedType, isNull);

      // Reset
      container.read(animalFilterProvider.notifier).setSearchQuery('Test');
      container.read(animalFilterProvider.notifier).reset();
      expect(container.read(animalFilterProvider).searchQuery, '');
      expect(container.read(animalFilterProvider).selectedType, isNull);
    });

    test('AnimalsRepositoryProvider returns an AnimalsRepository instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(animalsRepositoryProvider);
      expect(repo, isNotNull);
    });
  });
}

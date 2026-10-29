// test/unit/providers_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/locale_provider.dart';
import 'package:agritrack/providers/theme_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

      container
          .read(localeProvider.notifier)
          .setLocale(const Locale('fr', 'CI'));
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
      expect(
          container.read(animalFilterProvider).selectedType, AnimalType.caprin);

      // Toggling same type unselects it
      container.read(animalFilterProvider.notifier).setType(AnimalType.caprin);
      expect(container.read(animalFilterProvider).selectedType, isNull);

      // Reset
      container.read(animalFilterProvider.notifier).setSearchQuery('Test');
      container.read(animalFilterProvider.notifier).reset();
      expect(container.read(animalFilterProvider).searchQuery, '');
      expect(container.read(animalFilterProvider).selectedType, isNull);
    });

    test(
        'filteredAnimalsProvider filters by type, search query and handles whitespace',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for initial animals
      await container.read(animalsProvider.future);

      // Initial state: all 12 animals
      final all = container.read(filteredAnimalsProvider).value!;
      expect(all.length, 12);

      // Filter by type: Bovin (4 bovins in demo data: Bakary, Fanta, Koné, Djata)
      container.read(animalFilterProvider.notifier).setType(AnimalType.bovin);
      final bovins = container.read(filteredAnimalsProvider).value!;
      expect(bovins.length, 4);
      expect(bovins.every((a) => a.type == AnimalType.bovin), isTrue);

      // Combined filter: Bovin + Search with trailing/leading spaces " bakary "
      container
          .read(animalFilterProvider.notifier)
          .setSearchQuery('  bakary  ');
      final matched = container.read(filteredAnimalsProvider).value!;
      expect(matched.length, 1);
      expect(matched.first.name, 'Bakary');

      // Search with no results
      container
          .read(animalFilterProvider.notifier)
          .setSearchQuery('introuvable_xyz');
      final none = container.read(filteredAnimalsProvider).value!;
      expect(none, isEmpty);

      // Reset filter
      container.read(animalFilterProvider.notifier).reset();
      final reset = container.read(filteredAnimalsProvider).value!;
      expect(reset.length, 12);
    });

    test('speciesCountsProvider computes accurate real counts per species',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(animalsProvider.future);

      final counts = container.read(speciesCountsProvider);
      expect(counts[null], 12);
      expect(counts[AnimalType.bovin], 4);
      expect(counts[AnimalType.caprin], 3);
      expect(counts[AnimalType.ovin], 3);
      expect(counts[AnimalType.volaille], 2);
    });

    test('filteredAnimalsProvider sorts by name, weight, and expenses stably',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(animalsProvider.future);

      // Tri par Nom croissant (A-Z)
      container
          .read(animalFilterProvider.notifier)
          .setSort(AnimalSortCriteria.name, ascending: true);
      final sortedByName = container.read(filteredAnimalsProvider).value!;
      for (var i = 0; i < sortedByName.length - 1; i++) {
        expect(
          sortedByName[i]
                  .name
                  .toLowerCase()
                  .compareTo(sortedByName[i + 1].name.toLowerCase()) <=
              0,
          isTrue,
        );
      }

      // Inversion de tri (Z-A)
      container.read(animalFilterProvider.notifier).toggleSortDirection();
      final sortedByNameDesc = container.read(filteredAnimalsProvider).value!;
      for (var i = 0; i < sortedByNameDesc.length - 1; i++) {
        expect(
          sortedByNameDesc[i]
                  .name
                  .toLowerCase()
                  .compareTo(sortedByNameDesc[i + 1].name.toLowerCase()) >=
              0,
          isTrue,
        );
      }

      // Tri par Poids décroissant
      container
          .read(animalFilterProvider.notifier)
          .setSort(AnimalSortCriteria.weight, ascending: false);
      final sortedByWeightDesc = container.read(filteredAnimalsProvider).value!;
      for (var i = 0; i < sortedByWeightDesc.length - 1; i++) {
        expect(
            sortedByWeightDesc[i].weightKg >=
                sortedByWeightDesc[i + 1].weightKg,
            isTrue);
      }

      // Tri par Dépenses cumulées décroissantes
      container
          .read(animalFilterProvider.notifier)
          .setSort(AnimalSortCriteria.expenses, ascending: false);
      final sortedByExpenses = container.read(filteredAnimalsProvider).value!;
      for (var i = 0; i < sortedByExpenses.length - 1; i++) {
        expect(
            sortedByExpenses[i].totalExpenses >=
                sortedByExpenses[i + 1].totalExpenses,
            isTrue);
      }

      // Vérifie que les données persistées de base ne sont pas altérées
      final baseAnimals = await container.read(animalsProvider.future);
      expect(baseAnimals.length, 12);
    });

    test('AnimalsRepositoryProvider returns an AnimalsRepository instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(animalsRepositoryProvider);
      expect(repo, isNotNull);
    });

    test(
        'AnimalsNotifier adds an expense and updates animalsProvider and animalByIdProvider',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Load initial animals
      final initialAnimals = await container.read(animalsProvider.future);
      final target = initialAnimals.first;
      final initialTotal = target.totalExpenses;

      final expense = Expense(
        id: '',
        label: 'Vermifuge Bovin',
        amount: 4500,
        date: DateTime.now(),
        category: ExpenseCategory.sante,
      );

      final added =
          await container.read(animalsNotifierProvider.notifier).addExpense(
                animalId: target.id,
                expense: expense,
              );

      expect(added.id, isNotEmpty);
      expect(added.label, 'Vermifuge Bovin');

      // Verify animalByIdProvider is updated
      final updatedAnimal = container.read(animalByIdProvider(target.id));
      expect(updatedAnimal, isNotNull);
      expect(updatedAnimal!.totalExpenses, initialTotal + 4500);
      expect(updatedAnimal.expenses.any((e) => e.label == 'Vermifuge Bovin'),
          isTrue);
    });

    test(
        'expense outside current month affects totalExpenses but not monthlyExpenses if date differs',
        () async {
      final now = DateTime.now();
      final pastDate = DateTime(now.year - 1, 1, 1);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final animals = await container.read(animalsProvider.future);
      final target = animals.last;

      final initialTotal = target.totalExpenses;
      final initialMonthly = target.monthlyExpenses;

      await container.read(animalsNotifierProvider.notifier).addExpense(
            animalId: target.id,
            expense: Expense(
              id: '',
              label: 'Frais année passée',
              amount: 5000,
              date: pastDate,
              category: ExpenseCategory.autre,
            ),
          );

      final updated = container.read(animalByIdProvider(target.id));
      expect(updated!.totalExpenses, initialTotal + 5000);
      expect(updated.monthlyExpenses, initialMonthly);
    });

    test('AnimalsNotifier adds an animal and updates animalsProvider',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialAnimals = await container.read(animalsProvider.future);
      final initialCount = initialAnimals.length;

      final newAnimal = Animal(
        id: 'test_a999',
        name: 'Taureau Test',
        type: AnimalType.bovin,
        ageMonths: 30,
        weightKg: 400.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      final created = await container
          .read(animalsNotifierProvider.notifier)
          .addAnimal(newAnimal);

      expect(created.id, 'test_a999');
      expect(created.name, 'Taureau Test');

      final updatedAnimals = await container.read(animalsProvider.future);
      expect(updatedAnimals.length, initialCount + 1);
      expect(updatedAnimals.any((a) => a.id == 'test_a999'), isTrue);

      final liveAnimal = container.read(animalByIdProvider('test_a999'));
      expect(liveAnimal, isNotNull);
      expect(liveAnimal!.name, 'Taureau Test');
    });

    test(
        'AnimalsNotifier updates an animal and invalidates animalsProvider & animalByIdProvider',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialAnimals = await container.read(animalsProvider.future);
      final target = initialAnimals.first;

      final modified = target.copyWith(
        name: 'Nom Modifié Par Notifier',
        weightKg: 520.0,
      );

      final result = await container
          .read(animalsNotifierProvider.notifier)
          .updateAnimal(modified);

      expect(result.name, 'Nom Modifié Par Notifier');

      final updatedAnimals = await container.read(animalsProvider.future);
      final refreshedAnimal =
          updatedAnimals.firstWhere((a) => a.id == target.id);
      expect(refreshedAnimal.name, 'Nom Modifié Par Notifier');
      expect(refreshedAnimal.weightKg, 520.0);

      final liveById = container.read(animalByIdProvider(target.id));
      expect(liveById!.name, 'Nom Modifié Par Notifier');
    });
  });
}

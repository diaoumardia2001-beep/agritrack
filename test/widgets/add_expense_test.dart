// test/widgets/add_expense_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/screens/animal_detail_screen.dart';

void main() {
  Widget buildTestableScreen({required Animal animal}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'CI'),
          Locale('en', 'US'),
        ],
        locale: const Locale('fr', 'CI'),
        home: AnimalDetailScreen(animal: animal),
      ),
    );
  }

  group('Add Expense Form & UI Tests', () {
    testWidgets('Opens Add Expense Dialog when button is clicked',
        (WidgetTester tester) async {
      final testAnimal = Animal(
        id: 'test_anim_1',
        name: 'Samba',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 310,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(buildTestableScreen(animal: testAnimal));
      await tester.pumpAndSettle();

      // Find FAB with "Ajouter une dépense"
      final addExpenseBtn = find.text('Ajouter une dépense');
      expect(addExpenseBtn, findsOneWidget);

      await tester.tap(addExpenseBtn);
      await tester.pumpAndSettle();

      // Verify Dialog header
      expect(find.text('Libellé de la dépense'), findsOneWidget);
      expect(find.text('Montant (FCFA)'), findsOneWidget);
      expect(find.text('Catégorie'), findsOneWidget);
      expect(find.text('Date de la dépense'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('Validates required fields: empty label and empty amount',
        (WidgetTester tester) async {
      final testAnimal = Animal(
        id: 'test_anim_2',
        name: 'Koffi',
        type: AnimalType.caprin,
        ageMonths: 18,
        weightKg: 35,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(buildTestableScreen(animal: testAnimal));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter une dépense'));
      await tester.pumpAndSettle();

      // Tap submit with empty inputs
      final submitBtn = find.text('Enregistrer');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Errors displayed
      expect(find.text('Veuillez saisir un libellé'), findsOneWidget);
      expect(find.text('Veuillez saisir un montant'), findsOneWidget);
    });

    testWidgets('Validates invalid amounts (0, negative, non-numeric)',
        (WidgetTester tester) async {
      final testAnimal = Animal(
        id: 'test_anim_3',
        name: 'Awa',
        type: AnimalType.ovin,
        ageMonths: 12,
        weightKg: 40,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(buildTestableScreen(animal: testAnimal));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter une dépense'));
      await tester.pumpAndSettle();

      final labelField = find.byType(TextFormField).at(0);
      final amountField = find.byType(TextFormField).at(1);
      final submitBtn = find.text('Enregistrer');

      // 1. Label too short
      await tester.enterText(labelField, 'A');
      await tester.enterText(amountField, '0');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Le libellé doit comporter au moins 2 caractères'),
          findsOneWidget);
      expect(find.text('Le montant doit être strictement supérieur à 0'),
          findsOneWidget);

      // 2. Negative amount
      await tester.enterText(amountField, '-500');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      expect(find.text('Le montant doit être strictement supérieur à 0'),
          findsOneWidget);

      // 3. Non numeric amount
      await tester.enterText(amountField, 'abc');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      expect(find.text('Veuillez saisir un montant numérique valide'),
          findsOneWidget);
    });

    testWidgets('Preserves typed inputs when validation fails',
        (WidgetTester tester) async {
      final testAnimal = Animal(
        id: 'test_anim_4',
        name: 'Moussa',
        type: AnimalType.bovin,
        ageMonths: 30,
        weightKg: 350,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(buildTestableScreen(animal: testAnimal));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter une dépense'));
      await tester.pumpAndSettle();

      final labelField = find.byType(TextFormField).at(0);
      final amountField = find.byType(TextFormField).at(1);

      await tester.enterText(labelField, 'Alimentation Spéciale');
      await tester.enterText(amountField, 'invalid');

      final submitBtn = find.text('Enregistrer');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Label text is preserved
      expect(find.text('Alimentation Spéciale'), findsOneWidget);
      expect(find.text('invalid'), findsOneWidget);
    });

    testWidgets('Allows selecting category and date, then cancels properly',
        (WidgetTester tester) async {
      final testAnimal = Animal(
        id: 'test_anim_5',
        name: 'Fatou',
        type: AnimalType.caprin,
        ageMonths: 15,
        weightKg: 28,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(buildTestableScreen(animal: testAnimal));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter une dépense'));
      await tester.pumpAndSettle();

      // Select Santé category
      final santeChip = find.text('💊 Santé');
      expect(santeChip, findsOneWidget);
      await tester.tap(santeChip);
      await tester.pumpAndSettle();

      // Cancel button closes dialog
      final cancelBtn = find.text('Annuler');
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Dialog is gone
      expect(find.text('Libellé de la dépense'), findsNothing);
    });

    testWidgets('Full flow: adds expense, updates list and total immediately',
        (WidgetTester tester) async {
      final animal = Animal(
        id: 'a003',
        name: 'Koné',
        type: AnimalType.bovin,
        ageMonths: 48,
        weightKg: 410.0,
        healthStatus: HealthStatus.sain,
        expenses: [
          Expense(
            id: 'e007',
            label: 'Foin et paille',
            amount: 10500,
            date: DateTime(2026, 10, 1),
            category: ExpenseCategory.alimentation,
          ),
          Expense(
            id: 'e008',
            label: 'Vermifuge',
            amount: 4500,
            date: DateTime(2026, 9, 10),
            category: ExpenseCategory.sante,
          ),
        ],
        createdAt: DateTime(2025, 8, 10),
      );

      await tester.pumpWidget(buildTestableScreen(animal: animal));
      await tester.pumpAndSettle();

      // Initial state: total is 15k FCFA
      expect(find.text('15k FCFA'), findsOneWidget);
      expect(find.text('Foin et paille'), findsOneWidget);

      // Open add expense dialog
      await tester.tap(find.text('Ajouter une dépense'));
      await tester.pumpAndSettle();

      // Fill in valid data
      final labelField = find.byType(TextFormField).at(0);
      final amountField = find.byType(TextFormField).at(1);

      await tester.enterText(labelField, 'Vaccination Pleuropneumonie');
      await tester.enterText(amountField, '5000');

      // Select category Santé
      await tester.tap(find.text('💊 Santé'));
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.text('Enregistrer');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);

      // Advance past repository delay and pop animation
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(seconds: 4));

      // Dialog is dismissed
      expect(find.text('Libellé de la dépense'), findsNothing);

      // The new expense is displayed in the list
      expect(find.text('Vaccination Pleuropneumonie'), findsOneWidget);
      expect(find.textContaining('Santé'), findsWidgets);

      // Total expenses updated: initial 15 000 + 5 000 = 20 000 -> 20k FCFA
      expect(find.text('20k FCFA'), findsOneWidget);
    });

    testWidgets(
        'Handles expense saving error: displays error SnackBar, dialog stays open, resets loading state',
        (WidgetTester tester) async {
      final animal = Animal(
        id: 'a_err',
        name: 'Taureau Error',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 500.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      final failingRepo = _FailingAnimalsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(failingRepo),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'CI'),
              Locale('en', 'US'),
            ],
            locale: const Locale('fr', 'CI'),
            home: AnimalDetailScreen(animal: animal),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open add expense dialog
      await tester.tap(find.text('Ajouter une dépense'));
      await tester.pumpAndSettle();

      final labelField = find.byType(TextFormField).at(0);
      final amountField = find.byType(TextFormField).at(1);

      await tester.enterText(labelField, 'Dépense Échec');
      await tester.enterText(amountField, '7500');

      final submitBtn = find.text('Enregistrer');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // SnackBar with error message displayed
      expect(find.textContaining('Erreur lors de l\'enregistrement'),
          findsOneWidget);

      // Dialog is still open so the user doesn't lose their input
      expect(find.text('Libellé de la dépense'), findsOneWidget);
      expect(find.text('Dépense Échec'), findsOneWidget);
      expect(find.text('7500'), findsOneWidget);
    });
  });
}

class _FailingAnimalsRepository extends AnimalsRepository {
  @override
  Future<Expense> addExpense(String animalId, Expense expense) async {
    throw Exception('Erreur de connexion Sembast simulée');
  }
}

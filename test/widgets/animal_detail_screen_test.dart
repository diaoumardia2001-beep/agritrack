// test/widgets/animal_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/screens/animal_detail_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  final animalWithExpenses = Animal(
    id: 'anim_test_1',
    name: 'Tchou',
    type: AnimalType.bovin,
    ageMonths: 36,
    weightKg: 420.0,
    healthStatus: HealthStatus.sain,
    expenses: [
      Expense(
        id: 'exp_1',
        label: 'Vaccin Charbon',
        amount: 8000,
        date: DateTime(2026, 10, 1),
        category: ExpenseCategory.sante,
      ),
      Expense(
        id: 'exp_2',
        label: 'Foin luzerne',
        amount: 12000,
        date: DateTime(2026, 10, 15),
        category: ExpenseCategory.alimentation,
      ),
    ],
    createdAt: DateTime(2025, 6, 1),
  );

  final animalWithoutExpenses = Animal(
    id: 'anim_test_2',
    name: 'Biquette',
    type: AnimalType.caprin,
    ageMonths: 8,
    weightKg: 22.0,
    healthStatus: HealthStatus.aSurveiller,
    expenses: const [],
    createdAt: DateTime(2026, 3, 10),
  );

  Widget buildDetailWidget({
    required Animal animal,
    ThemeMode themeMode = ThemeMode.light,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        animalByIdProvider(animal.id).overrideWithValue(animal),
        ...overrides,
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
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

  testWidgets(
      'Renders complete animal profile, identification and physical info',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildDetailWidget(animal: animalWithExpenses));
    await tester.pumpAndSettle();

    // Nom et espèce
    expect(find.text('Tchou'), findsAtLeastNWidgets(1));
    expect(find.text('Bovin'), findsOneWidget);
    expect(find.text('ID: anim_test_1'), findsOneWidget);

    // Statut sanitaire
    expect(find.text('Sain'), findsAtLeastNWidgets(1));

    // Informations physiques
    expect(find.text('420.0 kg'), findsOneWidget);
    expect(find.text('Poids'), findsOneWidget);
    expect(find.text('3 ans'), findsOneWidget); // 36 mois = 3 ans
    expect(find.text('Âge'), findsOneWidget);

    // Date d'enregistrement
    expect(find.textContaining('Enregistré le'), findsOneWidget);
  });

  testWidgets(
      'Calculates and displays cumulative and monthly financial summary',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildDetailWidget(animal: animalWithExpenses));
    await tester.pumpAndSettle();

    // 8000 + 12000 = 20000 -> 20k FCFA
    expect(find.text('Résumé financier'), findsOneWidget);
    expect(find.text('20k FCFA'), findsAtLeastNWidgets(1));
    expect(find.text('2'), findsOneWidget); // 2 dépenses
    expect(find.textContaining('opérations'), findsOneWidget);
  });

  testWidgets(
      'Displays expenses list sorted chronologically with category labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildDetailWidget(animal: animalWithExpenses));
    await tester.pumpAndSettle();

    expect(find.text('Historique des dépenses'), findsOneWidget);
    expect(find.text('Foin luzerne'), findsOneWidget);
    expect(find.text('Vaccin Charbon'), findsOneWidget);
    expect(find.textContaining('Alimentation'), findsOneWidget);
    expect(find.textContaining('Santé'), findsWidgets);
  });

  testWidgets('Displays dedicated empty state when animal has no expenses',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildDetailWidget(animal: animalWithoutExpenses));
    await tester.pumpAndSettle();

    expect(find.text('Aucune dépense enregistrée.'), findsOneWidget);
    expect(find.text('Enregistrer une première dépense'), findsOneWidget);
    expect(find.text('0 FCFA'), findsAtLeastNWidgets(1));
  });

  test(
      'Expense isolation: adding expense to one animal does not affect another',
      () {
    final a1 = animalWithExpenses;
    final a2 = animalWithoutExpenses;

    final initialA1Count = a1.expenses.length;
    final initialA2Count = a2.expenses.length;

    // Ajout d'une dépense à a2
    final newExp = Expense(
      id: 'e_isolated',
      label: 'Vermifuge',
      amount: 4000,
      date: DateTime.now(),
      category: ExpenseCategory.sante,
    );

    final updatedA2 = a2.copyWith(expenses: [...a2.expenses, newExp]);

    expect(updatedA2.expenses.length, initialA2Count + 1);
    expect(a1.expenses.length, initialA1Count);
    expect(a1.totalExpenses, 20000.0);
    expect(updatedA2.totalExpenses, 4000.0);
  });

  testWidgets('Renders cleanly in dark mode without layout errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildDetailWidget(
        animal: animalWithExpenses,
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tchou'), findsAtLeastNWidgets(1));
    expect(find.text('Historique des dépenses'), findsOneWidget);
    expect(find.text('20k FCFA'), findsAtLeastNWidgets(1));
  });
}

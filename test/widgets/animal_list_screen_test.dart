// test/widgets/animal_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/screens/animal_detail_screen.dart';
import 'package:agritrack/screens/animal_list_screen.dart';
import 'package:agritrack/widgets/animal_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });
  final sampleAnimals = [
    Animal(
      id: 'a1',
      name: 'Bella',
      type: AnimalType.bovin,
      ageMonths: 24,
      weightKg: 450.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e1',
          label: 'Alimentation foin',
          amount: 15000,
          date: DateTime.now(),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 1, 10),
    ),
    Animal(
      id: 'a2',
      name: 'Cabri',
      type: AnimalType.caprin,
      ageMonths: 12,
      weightKg: 35.0,
      healthStatus: HealthStatus.aSurveiller,
      expenses: const [],
      createdAt: DateTime(2026, 2, 1),
    ),
    Animal(
      id: 'a3',
      name: 'Dolly',
      type: AnimalType.ovin,
      ageMonths: 18,
      weightKg: 55.0,
      healthStatus: HealthStatus.malade,
      expenses: const [],
      createdAt: DateTime(2026, 3, 5),
    ),
  ];

  Widget buildTestWidget({List<Animal>? animals}) {
    return ProviderScope(
      overrides: [
        animalsProvider.overrideWith((ref) async => animals ?? sampleAnimals),
      ],
      child: const MaterialApp(
        home: AnimalListScreen(),
      ),
    );
  }

  testWidgets('AnimalListScreen renders header with total count and cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Mon Cheptel'), findsOneWidget);
    expect(find.text('3 animaux • 3 espèces'), findsOneWidget);
    expect(find.byType(AnimalCard), findsNWidgets(3));
    expect(find.text('Bella'), findsOneWidget);
    expect(find.text('Cabri'), findsOneWidget);
    expect(find.text('Dolly'), findsOneWidget);
  });

  testWidgets('AnimalListScreen toggles between Grid and List view',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Trouve l'action de bascule
    final toggleButton = find.byTooltip('Passer en vue liste');
    expect(toggleButton, findsOneWidget);

    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Maintenant l'icône doit proposer de revenir en grille
    expect(find.byTooltip('Passer en vue grille'), findsOneWidget);
    expect(find.byType(AnimalCard), findsNWidgets(3));

    // Revenir en grille
    await tester.tap(find.byTooltip('Passer en vue grille'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Passer en vue liste'), findsOneWidget);
  });

  testWidgets('AnimalListScreen filters animals by species chip',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Sélectionne le filtre Bovin
    final bovinChip = find.text('🐄 Bovin');
    expect(bovinChip, findsOneWidget);

    await tester.tap(bovinChip);
    await tester.pumpAndSettle();

    // Seul Bella (Bovin) doit être visible
    expect(find.text('Bella'), findsOneWidget);
    expect(find.text('Cabri'), findsNothing);
    expect(find.text('Dolly'), findsNothing);
    expect(find.byType(AnimalCard), findsOneWidget);

    // Retour à "Tous"
    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimalCard), findsNWidgets(3));
  });

  testWidgets('AnimalListScreen searches animals reactively',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Saisie dans le champ de recherche
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'cabri');
    await tester.pumpAndSettle();

    expect(find.text('Cabri'), findsOneWidget);
    expect(find.text('Bella'), findsNothing);
    expect(find.text('Dolly'), findsNothing);

    // Effacer via le bouton de réinitialisation
    final resetButton = find.text('Réinitialiser');
    expect(resetButton, findsOneWidget);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.byType(AnimalCard), findsNWidgets(3));
  });

  testWidgets('AnimalListScreen shows empty search state with clear button',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'inexistant_xyz');
    await tester.pumpAndSettle();

    expect(find.text('Aucun animal trouvé'), findsOneWidget);
    expect(find.text('Effacer les filtres'), findsOneWidget);

    await tester.tap(find.text('Effacer les filtres'));
    await tester.pumpAndSettle();

    expect(find.byType(AnimalCard), findsNWidgets(3));
  });

  testWidgets('AnimalListScreen shows empty herd state when database is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget(animals: const []));
    await tester.pumpAndSettle();

    expect(find.text('Votre cheptel est vide'), findsOneWidget);
    expect(find.text('Ajouter un animal'), findsOneWidget);
    expect(find.byType(AnimalCard), findsNothing);
  });

  testWidgets('AnimalListScreen navigates to AnimalDetailScreen when tapped',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final bellaCard = find.text('Bella');
    await tester.tap(bellaCard);
    await tester.pumpAndSettle();

    expect(find.byType(AnimalDetailScreen), findsOneWidget);
    expect(find.text('Historique des dépenses'), findsOneWidget);
  });
}

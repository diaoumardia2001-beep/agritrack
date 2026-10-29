// test/widgets/dashboard_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/screens/dashboard_screen.dart';
import 'package:agritrack/widgets/agritrack_logo.dart';
import 'package:agritrack/widgets/species_avatar.dart';
import 'package:agritrack/widgets/species_distribution_chart.dart';

void main() {
  group('DashboardScreen Widget Tests', () {
    testWidgets('DashboardScreen renders KPIs, logo, and section headers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AgriTrackLogo), findsOneWidget);
      expect(find.text('Agri'), findsOneWidget);
      expect(find.text('Track'), findsOneWidget);
      expect(find.text('Tableau de bord'), findsOneWidget);
      expect(find.text('Animaux'), findsOneWidget);
      expect(find.text('Dépenses'), findsOneWidget);
      expect(find.text('Alertes'), findsOneWidget);
      expect(find.text('Poids Moyen'), findsOneWidget);
      expect(find.text('Actions rapides'), findsOneWidget);
      expect(find.text('Derniers ajouts'), findsOneWidget);
    });

    testWidgets(
        'DashboardScreen invokes onNavigateToHerd when "Voir tout" is tapped',
        (WidgetTester tester) async {
      bool navigated = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(
              onNavigateToHerd: () => navigated = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final viewAllButton = find.text('Voir tout');
      expect(viewAllButton, findsOneWidget);

      await tester.tap(viewAllButton);
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
    });

    testWidgets(
        'DashboardScreen displays EmptyState when animals list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aucun animal enregistré'), findsWidgets);
      expect(find.text('0 têtes'), findsNWidgets(2));
      expect(find.text('0 kg'), findsOneWidget);
    });
  });

  group('SpeciesDistributionChart Widget Tests', () {
    testWidgets(
        'SpeciesDistributionChart displays empty state when total is zero',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeciesDistributionChart(
              counts: {
                AnimalType.bovin: 0,
                AnimalType.caprin: 0,
                AnimalType.ovin: 0,
                AnimalType.volaille: 0,
              },
            ),
          ),
        ),
      );

      expect(find.text('Répartition du cheptel'), findsOneWidget);
      expect(find.text('0 têtes'), findsOneWidget);
      expect(find.text('Aucun animal enregistré'), findsOneWidget);
      expect(
          find.text('Ajoutez votre premier animal pour voir la répartition.'),
          findsOneWidget);
    });

    testWidgets('SpeciesDistributionChart displays single species with 100%',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeciesDistributionChart(
              counts: {
                AnimalType.bovin: 8,
                AnimalType.caprin: 0,
                AnimalType.ovin: 0,
                AnimalType.volaille: 0,
              },
            ),
          ),
        ),
      );

      expect(find.text('8 têtes'), findsOneWidget);
      expect(find.text('8'), findsNWidgets(2)); // Centre et légende
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Bovin'), findsOneWidget);
    });

    testWidgets(
        'SpeciesDistributionChart calculates multiple species proportions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeciesDistributionChart(
              counts: {
                AnimalType.bovin: 5,
                AnimalType.caprin: 3,
                AnimalType.ovin: 2,
                AnimalType.volaille: 0,
              },
            ),
          ),
        ),
      );

      expect(find.text('10 têtes'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget); // 5/10 = 50%
      expect(find.text('30%'), findsOneWidget); // 3/10 = 30%
      expect(find.text('20%'), findsOneWidget); // 2/10 = 20%
    });
  });

  group('SpeciesAvatar Widget Tests', () {
    testWidgets(
        'SpeciesAvatar renders vector pictogram for each species without emoji',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SpeciesAvatar(type: AnimalType.bovin),
                SpeciesAvatar(type: AnimalType.caprin),
                SpeciesAvatar(type: AnimalType.ovin),
                SpeciesAvatar(type: AnimalType.volaille),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SpeciesAvatar), findsNWidgets(4));
      expect(find.byIcon(Icons.agriculture_rounded), findsOneWidget);
      expect(find.byIcon(Icons.terrain_rounded), findsOneWidget);
      expect(find.byIcon(Icons.filter_vintage_rounded), findsOneWidget);
      expect(find.byIcon(Icons.egg_rounded), findsOneWidget);
    });
  });
}

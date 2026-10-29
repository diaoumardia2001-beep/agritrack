import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/app_database.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/shared_preferences_provider.dart';
import 'package:agritrack/screens/animal_detail_screen.dart';
import 'package:agritrack/screens/animal_list_screen.dart';
import 'package:agritrack/screens/dashboard_screen.dart';
import 'package:agritrack/screens/splash_screen.dart';
import 'package:agritrack/theme/app_theme.dart';
import 'package:agritrack/widgets/agritrack_logo.dart';
import 'package:agritrack/widgets/animal_card.dart';
import 'package:agritrack/widgets/species_avatar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Post-Audit Corrections Tests', () {
    testWidgets(
        '1. SplashScreen renders AgriTrack logo, title and loading state',
        (WidgetTester tester) async {
      final db = await AppDatabase.openInMemory(name: 'splash_test.db');
      final repo = AnimalsRepository(database: Future.value(db));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SplashScreen(
              minDuration: Duration(milliseconds: 300),
            ),
          ),
        ),
      );

      // Verify logo and brand presence
      expect(find.byType(AgriTrackLogo), findsOneWidget);
      expect(find.text('Agri'), findsOneWidget);
      expect(find.text('Track'), findsOneWidget);
      expect(find.text('GESTION & SUIVI DE CHEPTEL'), findsOneWidget);
      expect(find.text('Chargement des données locales...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let animation settle and navigation trigger
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
    });

    testWidgets(
        '2. AnimalCard displays photo banner, species badge and health status',
        (WidgetTester tester) async {
      final animal = Animal(
        id: 'a001',
        name: 'Bakary',
        type: AnimalType.bovin,
        imageUrl: 'assets/images/bovin.jpg',
        ageMonths: 36,
        weightKg: 320.0,
        healthStatus: HealthStatus.sain,
        expenses: [
          Expense(
            id: 'e1',
            label: 'Foin',
            amount: 8500,
            date: DateTime(2026, 1, 1),
            category: ExpenseCategory.alimentation,
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AnimalCard(
              animal: animal,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Bakary'), findsOneWidget);
      expect(find.text('Bovin'), findsOneWidget);
      expect(find.text('320.0kg'), findsOneWidget);
      expect(find.text('36m'), findsOneWidget);
      expect(find.text('9k FCFA'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets(
        '3. SpeciesAvatar falls back gracefully to vector glyph when imageUrl is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeciesAvatar(
              type: AnimalType.caprin,
              imageUrl: null,
            ),
          ),
        ),
      );

      expect(find.byType(SpeciesAvatar), findsOneWidget);
      expect(find.byIcon(Icons.terrain_rounded), findsOneWidget);
    });

    testWidgets(
        '4. DashboardScreen collapses without any RenderFlex overflow during scroll',
        (WidgetTester tester) async {
      final db = await AppDatabase.openInMemory(name: 'dash_scroll_test.db');
      final repo = AnimalsRepository(database: Future.value(db));
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(repo),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down (causing FlexibleSpaceBar to collapse)
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Scroll to bottom
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '5. AnimalDetailScreen scrolls and collapses without right overflow',
        (WidgetTester tester) async {
      final db = await AppDatabase.openInMemory(name: 'detail_scroll_test.db');
      final repo = AnimalsRepository(database: Future.value(db));
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final animal = AnimalsRepository.demoAnimals.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(repo),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: AnimalDetailScreen(animal: animal),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check on mount (0 overflow)
      expect(tester.takeException(), isNull);

      // Scroll down causing SliverAppBar collapse
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '6. AnimalListScreen renders skeleton loading state when async is loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsProvider
                .overrideWith((ref) => Completer<List<Animal>>().future),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AnimalListScreen(),
          ),
        ),
      );
      await tester.pump();

      // List skeleton should be rendered
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '7. Cheptel exhibits ZERO right overflow across 320, 360, 390, 768, 1024, 1440 px',
        (WidgetTester tester) async {
      final complexHerd = [
        Animal(
          id: 'a_1729601234567890_normandie_tres_long',
          name: 'Marguerite Reine de Normandie la Première Extraordinaire',
          type: AnimalType.volaille,
          ageMonths: 120,
          weightKg: 1450.5,
          healthStatus: HealthStatus.aSurveiller,
          expenses: [
            Expense(
              id: 'e1',
              label: 'Alimentation spéciale grain bio renforcé',
              amount: 1500000,
              date: DateTime.now(),
              category: ExpenseCategory.alimentation,
            ),
          ],
          createdAt: DateTime(2026, 1, 10),
        ),
        Animal(
          id: 'a_1729601234567891_caprin_royal',
          name: 'Bouc Royal des Montagnes du Sud-Ouest Africain',
          type: AnimalType.caprin,
          ageMonths: 48,
          weightKg: 85.0,
          healthStatus: HealthStatus.malade,
          expenses: const [],
          createdAt: DateTime(2026, 2, 1),
        ),
      ];

      const testWidths = [320.0, 360.0, 390.0, 768.0, 1024.0, 1440.0];

      for (final width in testWidths) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              animalsProvider.overrideWith((ref) async => complexHerd),
            ],
            child: const MaterialApp(
              home: AnimalListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Débordement détecté en vue grille à ${width}px');

        // Bascule en vue liste
        final toggleBtn = find.byTooltip('Passer en vue liste');
        if (toggleBtn.evaluate().isNotEmpty) {
          await tester.tap(toggleBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'Débordement détecté en vue liste à ${width}px');
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('8. SplashScreen uses unified background and short duration',
        (WidgetTester tester) async {
      final db = await AppDatabase.openInMemory(name: 'splash_timing_test.db');
      final repo = AnimalsRepository(database: Future.value(db));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Verify that default minDuration is snappy (150ms)
      final splashWidget =
          tester.widget<SplashScreen>(find.byType(SplashScreen));
      expect(splashWidget.minDuration, const Duration(milliseconds: 150));

      // Verify canonical AgriTrackLogo is rendered
      expect(find.byType(AgriTrackLogo), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

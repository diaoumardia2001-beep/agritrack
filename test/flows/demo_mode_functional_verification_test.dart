// test/flows/demo_mode_functional_verification_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/core/demo_mode_config.dart';
import 'package:agritrack/core/supabase_config.dart';
import 'package:agritrack/data/database/demo_database_manager.dart';
import 'package:agritrack/main.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/sync_provider.dart';
import 'package:agritrack/services/sync/supabase_sync_client.dart';
import 'package:agritrack/widgets/demo_recruiter_banner.dart';

void main() {
  setUp(() async {
    await DemoDatabaseManager.closeAndReset();
    DemoModeConfig.setOverrideForTesting(null);
  });

  tearDown(() async {
    await DemoDatabaseManager.closeAndReset();
    DemoModeConfig.setOverrideForTesting(null);
  });

  group('Vérification Fonctionnelle Complète — Mode Démonstration AgriTrack', () {
    // ─── Point 1 & 2 : Lancement Web avec ?demo=true et affichage du bandeau ──
    testWidgets(
      'Point 1 & 2 : Détection ?demo=true et affichage du bandeau recruteur',
      (WidgetTester tester) async {
        // 1. Détection URL
        final demoUri = Uri.parse('https://agritrack-olive.vercel.app/?demo=true');
        expect(DemoModeConfig.isDemoMode(demoUri), isTrue);

        // 2. Lancement en mode démo
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isDemoModeProvider.overrideWith(
                (ref) => DemoModeNotifier(initialValue: true),
              ),
            ],
            child: const AgriTrackApp(skipSplash: true),
          ),
        );
        await tester.pumpAndSettle();

        // Vérification présence bandeau
        expect(find.byType(DemoRecruiterBanner), findsOneWidget);
        expect(
          find.text('Mode démonstration — données fictives et temporaires'),
          findsOneWidget,
        );
        expect(find.text('DÉMO'), findsOneWidget);
        expect(find.text('Réinitialiser la démo'), findsOneWidget);
      },
    );

    // ─── Point 3 : Présence des 12 animaux et 25 dépenses initiales ──────────
    testWidgets(
      'Point 3 : Présence initiale stricte des 12 animaux et 25 dépenses',
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          final repo = container.read(animalsRepositoryProvider);
          final animals = await repo.fetchAnimals();

          // 12 animaux
          expect(animals.length, equals(12));
          expect(animals.every((a) => a.isDemo), isTrue);

          // Identifiants attendus a001 à a012
          final ids = animals.map((a) => a.id).toSet();
          for (int i = 1; i <= 12; i++) {
            final expectedId = 'a${i.toString().padLeft(3, '0')}';
            expect(ids.contains(expectedId), isTrue,
                reason: 'L\'animal $expectedId doit être présent');
          }

          // 25 dépenses au total
          final totalExpenses =
              animals.fold<int>(0, (sum, a) => sum + a.expenses.length);
          expect(totalExpenses, equals(25));
        });
      },
    );

    // ─── Point 4 : Ajout, modification et suppression d'un animal ────────────
    testWidgets(
      'Point 4 : Cycle de vie complet d\'un animal (ajout, modif, suppression)',
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          final repo = container.read(animalsRepositoryProvider);

          // 1. Ajout
          final newAnimal = Animal(
            id: 'demo_test_animal_4',
            name: 'Bélier Test Recruteur',
            type: AnimalType.ovin,
            ageMonths: 18,
            weightKg: 55.0,
            healthStatus: HealthStatus.sain,
            expenses: const [],
            createdAt: DateTime.now(),
            isDemo: true,
          );

          await repo.addAnimal(newAnimal);
          var list = await repo.fetchAnimals();
          expect(list.length, equals(13));
          expect(list.any((a) => a.id == 'demo_test_animal_4'), isTrue);

          // 2. Modification
          final toUpdate = newAnimal.copyWith(
            weightKg: 58.5,
            healthStatus: HealthStatus.aSurveiller,
          );
          await repo.updateAnimal(toUpdate);
          final fetched = await repo.getAnimalById('demo_test_animal_4');
          expect(fetched, isNotNull);
          expect(fetched!.weightKg, equals(58.5));
          expect(fetched.healthStatus, equals(HealthStatus.aSurveiller));

          // 3. Suppression
          await repo.deleteAnimal('demo_test_animal_4');
          list = await repo.fetchAnimals();
          expect(list.length, equals(12));
          expect(list.any((a) => a.id == 'demo_test_animal_4'), isFalse);
        });
      },
    );

    // ─── Point 5 : Ajout, modification et suppression d'une dépense ──────────
    testWidgets(
      'Point 5 : Cycle de vie complet d\'une dépense (ajout, modif, suppression)',
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          final repo = container.read(animalsRepositoryProvider);

          final initialAnimal = await repo.getAnimalById('a001');
          expect(initialAnimal, isNotNull);
          final initialExpenseCount = initialAnimal!.expenses.length;

          // 1. Ajout dépense
          final newExpense = Expense(
            id: 'demo_exp_test_5',
            animalId: 'a001',
            label: 'Complément Minéral Recruteur',
            amount: 12000,
            date: DateTime.now(),
            category: ExpenseCategory.alimentation,
          );

          await repo.addExpense('a001', newExpense);
          var updatedAnimal = await repo.getAnimalById('a001');
          expect(updatedAnimal!.expenses.length, equals(initialExpenseCount + 1));
          expect(updatedAnimal.expenses.any((e) => e.id == 'demo_exp_test_5'), isTrue);

          // 2. Modification dépense
          final updatedExpense = newExpense.copyWith(amount: 15500);
          await repo.updateExpense('a001', updatedExpense);
          updatedAnimal = await repo.getAnimalById('a001');
          final foundExp =
              updatedAnimal!.expenses.firstWhere((e) => e.id == 'demo_exp_test_5');
          expect(foundExp.amount, equals(15500));

          // 3. Suppression dépense
          await repo.deleteExpense('a001', 'demo_exp_test_5');
          updatedAnimal = await repo.getAnimalById('a001');
          expect(updatedAnimal!.expenses.length, equals(initialExpenseCount));
          expect(updatedAnimal.expenses.any((e) => e.id == 'demo_exp_test_5'), isFalse);
        });
      },
    );

    // ─── Point 6 : Actualisation en direct des statistiques ──────────────────
    testWidgets(
      'Point 6 : Réactivité des KPI et statistiques du Dashboard en mode démo',
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          // Attendre le chargement initial de animalsProvider
          await container.read(animalsProvider.future);
          final initialStats = container.read(dashboardStatsProvider).value!;
          expect(initialStats.totalAnimals, equals(12));
          final initialAlerts = initialStats.healthAlerts;
          final initialMonthly = initialStats.totalMonthlyExpenses;

          // Ajouter un animal malade avec une dépense ce mois-ci
          final repo = container.read(animalsRepositoryProvider);
          final sickAnimal = Animal(
            id: 'demo_sick_animal',
            name: 'Vache Malade Test',
            type: AnimalType.bovin,
            ageMonths: 36,
            weightKg: 420.0,
            healthStatus: HealthStatus.malade,
            expenses: [
              Expense(
                id: 'exp_sick_vet',
                animalId: 'demo_sick_animal',
                label: 'Soins vétérinaires urgents',
                amount: 35000,
                date: DateTime.now(),
                category: ExpenseCategory.sante,
              ),
            ],
            createdAt: DateTime.now(),
            isDemo: true,
          );

          await repo.addAnimal(sickAnimal);
          container.invalidate(animalsProvider);
          await container.read(animalsProvider.future);

          final updatedStats = container.read(dashboardStatsProvider).value!;
          expect(updatedStats.totalAnimals, equals(13));
          expect(updatedStats.healthAlerts, equals(initialAlerts + 1));
          expect(updatedStats.totalMonthlyExpenses, equals(initialMonthly + 35000));

          // Supprimer l'animal pour vérifier le retour aux stats initiales
          await repo.deleteAnimal('demo_sick_animal');
          container.invalidate(animalsProvider);
          await container.read(animalsProvider.future);

          final restoredStats = container.read(dashboardStatsProvider).value!;
          expect(restoredStats.totalAnimals, equals(12));
          expect(restoredStats.healthAlerts, equals(initialAlerts));
          expect(restoredStats.totalMonthlyExpenses, equals(initialMonthly));
        });
      },
    );

    // ─── Point 7 : Bouton « Réinitialiser la démo » avec confirmation ────────
    testWidgets(
      'Point 7 : Fonctionnement du bouton « Réinitialiser la démo » et restauration',
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Altérer les données initiales
        await tester.runAsync(() async {
          final repo = container.read(animalsRepositoryProvider);
          await repo.fetchAnimals();
          await repo.deleteAnimal('a001');
          await repo.deleteAnimal('a002');
          final listAfterDelete = await repo.fetchAnimals();
          expect(listAfterDelete.length, equals(10));
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: DemoRecruiterBanner(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Cliquer sur 'Réinitialiser la démo'
        await tester.tap(find.text('Réinitialiser la démo'));
        await tester.pumpAndSettle();

        // 2. Vérifier la boîte de dialogue
        expect(find.text('Réinitialiser la démonstration ?'), findsOneWidget);
        expect(find.text('Annuler'), findsOneWidget);

        // 3. Annuler -> données restent à 10
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(find.text('Réinitialiser la démonstration ?'), findsNothing);

        await tester.runAsync(() async {
          final repo = container.read(animalsRepositoryProvider);
          final list = await repo.fetchAnimals();
          expect(list.length, equals(10));
        });

        // 4. Cliquer à nouveau et Confirmer
        await tester.tap(find.text('Réinitialiser la démo'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Réinitialiser'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 5. Vérifier le SnackBar de confirmation
        expect(
          find.text('Données de démonstration réinitialisées avec succès !'),
          findsOneWidget,
        );

        // 6. Vérifier la restauration intégrale (12 animaux, 25 dépenses)
        await tester.runAsync(() async {
          final repo = container.read(animalsRepositoryProvider);
          final restoredList = await repo.fetchAnimals();
          expect(restoredList.length, equals(12));
          expect(restoredList.any((a) => a.id == 'a001'), isTrue);
          expect(restoredList.any((a) => a.id == 'a002'), isTrue);

          final totalExpenses =
              restoredList.fold<int>(0, (sum, a) => sum + a.expenses.length);
          expect(totalExpenses, equals(25));
        });

        ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
            .hideCurrentSnackBar();
        await tester.pump();
      },
    );

    // ─── Point 8 : Volatilité totale après rechargement de la page ───────────
    testWidgets(
      'Point 8 : Volatilité en mémoire — disparition des mutations après rechargement',
      (WidgetTester tester) async {
        // Session 1 : L'utilisateur visite et ajoute un animal
        final container1 = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );

        await tester.runAsync(() async {
          final repo1 = container1.read(animalsRepositoryProvider);
          await repo1.addAnimal(Animal(
            id: 'temp_visitor_point_8',
            name: 'Visiteur Éphémère',
            type: AnimalType.bovin,
            ageMonths: 12,
            weightKg: 200.0,
            healthStatus: HealthStatus.sain,
            expenses: const [],
            createdAt: DateTime.now(),
            isDemo: true,
          ));
          final list1 = await repo1.fetchAnimals();
          expect(list1.length, equals(13));
        });
        container1.dispose();

        // Simulation Rechargement complet de la page (F5 / page refresh)
        // La mémoire vive du navigateur est détruite et reconstruite
        await DemoDatabaseManager.closeAndReset();

        // Session 2 : Nouvelle session après refresh
        final container2 = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );
        addTearDown(container2.dispose);

        await tester.runAsync(() async {
          final repo2 = container2.read(animalsRepositoryProvider);
          final list2 = await repo2.fetchAnimals();

          // L'animal éphémère a disparu
          expect(list2.length, equals(12));
          expect(list2.any((a) => a.id == 'temp_visitor_point_8'), isFalse);

          // Les 12 animaux d'origine et 25 dépenses sont intacts
          final totalExpenses =
              list2.fold<int>(0, (sum, a) => sum + a.expenses.length);
          expect(totalExpenses, equals(25));
        });
      },
    );

    // ─── Point 9 : Blocage total des lectures/écritures Supabase Cloud ───────
    test(
      'Point 9 : Blocage total de Supabase Cloud et des files de synchronisation',
      () async {
        DemoModeConfig.setOverrideForTesting(true);

        // 1. safeClient est null
        expect(SupabaseConfig.safeClient, isNull);

        // 2. Accès direct à client lance StateError
        expect(() => SupabaseConfig.client, throwsStateError);

        // 3. Client de synchronisation injecté est désactivé
        final container = ProviderContainer(
          overrides: [
            isDemoModeProvider.overrideWith(
              (ref) => DemoModeNotifier(initialValue: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        final syncClient = container.read(supabaseSyncClientProvider);
        expect(syncClient, isA<DisabledSupabaseSyncClient>());
        expect(
          () => syncClient.pushAnimalRpc(
            operationId: 'op_test',
            farmId: 'farm_test',
            action: 'create',
          ),
          throwsStateError,
        );

        // 4. File d'attente de synchronisation reste vide
        final queueService = container.read(syncQueueServiceProvider);
        final queue = await queueService.getAllOperations();
        expect(queue, isEmpty);
      },
    );

    // ─── Point 10 : Non-régression du mode standard (demo=false) ─────────────
    testWidgets(
      'Point 10 : Mode normal non affecté lorsque demo=false ou absent',
      (WidgetTester tester) async {
        // 1. Détection sans paramètre
        final standardUri = Uri.parse('https://agritrack-olive.vercel.app');
        expect(DemoModeConfig.isDemoMode(standardUri), isFalse);

        // 2. Rendu sans bandeau de démo
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isDemoModeProvider.overrideWith(
                (ref) => DemoModeNotifier(initialValue: false),
              ),
            ],
            child: const AgriTrackApp(skipSplash: true),
          ),
        );
        await tester.pumpAndSettle();

        // Le bandeau ne doit PAS apparaître
        expect(find.byType(DemoRecruiterBanner), findsNothing);
        expect(
          find.text('Mode démonstration — données fictives et temporaires'),
          findsNothing,
        );
      },
    );
  });
}


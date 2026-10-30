// test/widgets/demo_recruiter_banner_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/core/demo_mode_config.dart';
import 'package:agritrack/data/database/demo_database_manager.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/widgets/demo_recruiter_banner.dart';

void main() {
  group('DemoRecruiterBanner Widget Tests', () {
    tearDown(() async {
      await DemoDatabaseManager.closeAndReset();
      DemoModeConfig.setOverrideForTesting(null);
    });

    testWidgets('Renders banner elements correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isDemoModeProvider
                .overrideWith((ref) => DemoModeNotifier(initialValue: true)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DemoRecruiterBanner(),
            ),
          ),
        ),
      );

      // Verify banner label
      expect(find.text('DÉMO'), findsOneWidget);
      expect(
        find.text('Mode démonstration — données fictives et temporaires'),
        findsOneWidget,
      );

      // Verify reset button
      expect(find.text('Réinitialiser la démo'), findsOneWidget);
    });

    testWidgets(
        'Clicking reset button shows confirmation dialog and cancelling dismisses it',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isDemoModeProvider
                .overrideWith((ref) => DemoModeNotifier(initialValue: true)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DemoRecruiterBanner(),
            ),
          ),
        ),
      );

      // Tap reset button
      await tester.tap(find.text('Réinitialiser la démo'));
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('Réinitialiser la démonstration ?'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Réinitialiser'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Dialog should be gone
      expect(find.text('Réinitialiser la démonstration ?'), findsNothing);
    });

    testWidgets(
        'Confirming reset invokes resetDemoData and shows confirmation snackbar',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          isDemoModeProvider
              .overrideWith((ref) => DemoModeNotifier(initialValue: true)),
        ],
      );
      addTearDown(container.dispose);

      // Mutate by deleting an animal inside runAsync
      await tester.runAsync(() async {
        final repo = container.read(animalsRepositoryProvider);
        await repo.fetchAnimals();
        await repo.deleteAnimal('a001');
        final listBefore = await repo.fetchAnimals();
        expect(listBefore.length, equals(11));
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

      // Tap reset button
      await tester.tap(find.text('Réinitialiser la démo'));
      await tester.pumpAndSettle();

      // Tap Confirm 'Réinitialiser' in dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Réinitialiser'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify snackbar appears
      expect(
        find.text('Données de démonstration réinitialisées avec succès !'),
        findsOneWidget,
      );

      // Verify repo was restored to 12 animals
      await tester.runAsync(() async {
        final repo = container.read(animalsRepositoryProvider);
        final listAfter = await repo.fetchAnimals();
        expect(listAfter.length, equals(12));
        expect(listAfter.any((a) => a.id == 'a001'), isTrue);
      });

      // Dismiss snackbar
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
          .hideCurrentSnackBar();
      await tester.pump();
    });
  });
}


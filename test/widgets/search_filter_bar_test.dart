// test/widgets/search_filter_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/widgets/search_filter_bar.dart';

void main() {
  testWidgets('SearchFilterBar renders search field and filter chips',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animalsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchFilterBar(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tous'), findsAtLeastNWidgets(1));
  });

  testWidgets('SearchFilterBar with species counts reproduces chips layout',
      (WidgetTester tester) async {
    final animals = [
      ...List.generate(
          4,
          (i) => Animal(
                id: 'b$i',
                name: 'Bovin $i',
                type: AnimalType.bovin,
                ageMonths: 12,
                weightKg: 200,
                healthStatus: HealthStatus.sain,
                expenses: const [],
                createdAt: DateTime(2026, 1, 1),
              )),
      ...List.generate(
          3,
          (i) => Animal(
                id: 'c$i',
                name: 'Caprin $i',
                type: AnimalType.caprin,
                ageMonths: 12,
                weightKg: 40,
                healthStatus: HealthStatus.sain,
                expenses: const [],
                createdAt: DateTime(2026, 1, 1),
              )),
      ...List.generate(
          3,
          (i) => Animal(
                id: 'o$i',
                name: 'Ovin $i',
                type: AnimalType.ovin,
                ageMonths: 12,
                weightKg: 50,
                healthStatus: HealthStatus.sain,
                expenses: const [],
                createdAt: DateTime(2026, 1, 1),
              )),
      ...List.generate(
          2,
          (i) => Animal(
                id: 'v$i',
                name: 'Volaille $i',
                type: AnimalType.volaille,
                ageMonths: 4,
                weightKg: 2,
                healthStatus: HealthStatus.sain,
                expenses: const [],
                createdAt: DateTime(2026, 1, 1),
              )),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animalsProvider.overrideWith((ref) async => animals),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SearchFilterBar(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tous'), findsAtLeastNWidgets(1));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('🐄 Bovin'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('🐐 Caprin'), findsOneWidget);
    expect(find.text('3'), findsAtLeastNWidgets(1));
    expect(find.text('🐓 Volaille'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tap on Bovin filter
    await tester.tap(find.text('🐄 Bovin'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tap back to Tous
    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'SearchFilterBar exhibits ZERO overflow across 320, 360, 390, 768, 1200px',
      (WidgetTester tester) async {
    final animals = [
      ...List.generate(
          14,
          (i) => Animal(
                id: 'b_$i',
                name: 'Bovin Extraordinaire de Race pure $i',
                type: AnimalType.bovin,
                ageMonths: 24,
                weightKg: 450,
                healthStatus: HealthStatus.sain,
                expenses: const [],
                createdAt: DateTime(2026, 1, 1),
              )),
      ...List.generate(
          8,
          (i) => Animal(
                id: 'v_$i',
                name: 'Volaille Fermière $i',
                type: AnimalType.volaille,
                ageMonths: 6,
                weightKg: 3,
                healthStatus: HealthStatus.sain,
                expenses: const [],
                createdAt: DateTime(2026, 1, 1),
              )),
    ];

    const widths = [320.0, 360.0, 390.0, 768.0, 1200.0];
    for (final width in widths) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animalsProvider.overrideWith((ref) async => animals),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SearchFilterBar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Overflow detected at width ${width}px');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// test/widgets/animal_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/widgets/animal_card.dart';

void main() {
  testWidgets('AnimalCard displays animal name, type, weight and triggers onTap',
      (WidgetTester tester) async {
    bool tapped = false;
    final animal = Animal(
      id: 'a1',
      name: 'Bella',
      type: AnimalType.caprin,
      ageMonths: 18,
      weightKg: 42.5,
      healthStatus: HealthStatus.sain,
      expenses: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimalCard(
            animal: animal,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Bella'), findsOneWidget);
    expect(find.text('Caprin'), findsOneWidget);
    expect(find.text('42.5kg'), findsOneWidget);
    expect(find.text('18m'), findsOneWidget);

    await tester.tap(find.byType(AnimalCard));
    expect(tapped, isTrue);
  });
}

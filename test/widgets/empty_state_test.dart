// test/widgets/empty_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState displays title, subtitle and icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.pets,
            title: 'Aucun animal',
            subtitle: 'Ajoutez votre premier animal pour commencer.',
          ),
        ),
      ),
    );

    expect(find.text('Aucun animal'), findsOneWidget);
    expect(find.text('Ajoutez votre premier animal pour commencer.'), findsOneWidget);
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });
}

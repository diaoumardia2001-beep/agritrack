// test/flows/add_animal_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/main.dart';

void main() {
  testWidgets('Flow 2: Complete animal creation form and submission',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AgriTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Navigate to Add Animal Tab
    final addTab = find.text('Ajouter');
    expect(addTab, findsOneWidget);
    await tester.tap(addTab);
    await tester.pumpAndSettle();

    // 2. Verify form is present
    expect(find.text('Ajouter un animal'), findsOneWidget);

    // 3. Enter Name
    final nameField = find.byType(TextFormField).at(0);
    await tester.enterText(nameField, 'Bandiagara');
    await tester.pumpAndSettle();

    // 4. Enter Age
    final ageField = find.byType(TextFormField).at(1);
    await tester.enterText(ageField, '20');
    await tester.pumpAndSettle();

    // 5. Enter Weight
    final weightField = find.byType(TextFormField).at(2);
    await tester.enterText(weightField, '175.5');
    await tester.pumpAndSettle();

    // 6. Submit Form
    final submitButton = find.text('Ajouter l\'animal');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // 7. Verify Success Confirmation
    expect(find.text('Bandiagara ajouté avec succès ! 🐄'), findsOneWidget);

    // Wait for refetch and snackbar timers to settle
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

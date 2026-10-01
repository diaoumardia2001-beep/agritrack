// integration_test/add_animal_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:agritrack/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End Flow 2: Add a new animal via form',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AgriTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to Add Animal Tab (index 2)
    final addTab = find.text('Ajouter');
    expect(addTab, findsOneWidget);
    await tester.tap(addTab);
    await tester.pumpAndSettle();

    // Verify Add Animal screen is shown
    expect(find.text('Nouvel Animal'), findsOneWidget);

    // Enter name
    final nameField = find.byType(TextFormField).at(0);
    await tester.enterText(nameField, 'Bandiagara');
    await tester.pumpAndSettle();

    // Enter age
    final ageField = find.byType(TextFormField).at(1);
    await tester.enterText(ageField, '20');
    await tester.pumpAndSettle();

    // Enter weight
    final weightField = find.byType(TextFormField).at(2);
    await tester.enterText(weightField, '175.5');
    await tester.pumpAndSettle();

    // Tap submit button
    final submitButton = find.text('Enregistrer l\'animal');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify confirmation snackbar
    expect(find.text('Bandiagara a été ajouté avec succès ! 🎉'), findsOneWidget);
  });
}

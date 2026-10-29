// test/flows/app_flow_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/main.dart';
import 'package:agritrack/widgets/animal_card.dart';

void main() {
  testWidgets('Flow 1: Complete navigation from Dashboard to Herd and Detail',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AgriTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Check Dashboard KPIs
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Agri'), findsWidgets);
    expect(find.text('Track'), findsWidgets);

    // 2. Switch to Herd screen
    final herdTab = find.text('Cheptel');
    expect(herdTab, findsOneWidget);
    await tester.tap(herdTab);
    await tester.pumpAndSettle();

    // 3. Verify herd screen loaded with cards
    expect(find.text('Mon Cheptel'), findsOneWidget);
    expect(find.byType(AnimalCard), findsWidgets);

    // 4. Tap first animal card to navigate to detail
    final firstCard = find.byType(AnimalCard).first;
    await tester.tap(firstCard);
    await tester.pumpAndSettle();

    // 5. Verify Detail screen
    expect(find.text('Historique des dépenses'), findsOneWidget);
    expect(find.text('Poids'), findsOneWidget);
  });

  testWidgets(
      'Flow 1b: Tapping "Voir tout" on Dashboard navigates to Mon Cheptel tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AgriTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initially on Dashboard
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Derniers ajouts'), findsOneWidget);

    // Tap "Voir tout"
    final viewAllButton = find.text('Voir tout');
    expect(viewAllButton, findsOneWidget);
    await tester.tap(viewAllButton);
    await tester.pumpAndSettle();

    // Verify Herd screen is now active
    expect(find.text('Mon Cheptel'), findsOneWidget);
    expect(find.byType(AnimalCard), findsWidgets);
  });
}

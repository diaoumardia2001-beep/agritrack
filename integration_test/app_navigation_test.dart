import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:agritrack/main.dart';
import 'package:agritrack/widgets/animal_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End Flow 1: Browse dashboard and view animal detail',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AgriTrackApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dashboard is displayed
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('AgriTrack'), findsOneWidget);

    // Switch to Herd Tab (index 1)
    final herdTab = find.text('Cheptel');
    expect(herdTab, findsOneWidget);
    await tester.tap(herdTab);
    await tester.pumpAndSettle();

    // Verify Herd screen is displayed with search bar and animal cards
    expect(find.text('Mon Cheptel'), findsOneWidget);
    expect(find.byType(AnimalCard), findsWidgets);

    // Tap on the first animal card to navigate to detail
    final firstCard = find.byType(AnimalCard).first;
    await tester.tap(firstCard);
    await tester.pumpAndSettle();

    // Verify Detail screen
    expect(find.text('Dépenses cumulées'), findsOneWidget);
    expect(find.text('Ajouter une dépense'), findsOneWidget);

    // Go back
    final backButton = find.byTooltip('Back');
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await tester.pumpAndSettle();
    }
  });
}

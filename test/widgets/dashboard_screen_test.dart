// test/widgets/dashboard_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/screens/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen renders KPIs and species cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AgriTrack 🌿'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Animaux'), findsOneWidget);
  });
}

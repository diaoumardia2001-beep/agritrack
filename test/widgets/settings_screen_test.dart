// test/widgets/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen displays theme and toggles dark mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Thème'), findsOneWidget);
    expect(find.text('Langue de l\'application'), findsOneWidget);

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pump();
  });
}

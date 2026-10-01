// test/widgets/search_filter_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/widgets/search_filter_bar.dart';

void main() {
  testWidgets('SearchFilterBar renders search field and filter chips',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SearchFilterBar(),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tous'), findsAtLeastNWidgets(1));
    expect(find.text('🐄 Bovin'), findsOneWidget);
    expect(find.text('🐐 Caprin'), findsOneWidget);
  });
}

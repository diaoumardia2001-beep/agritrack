// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agritrack/main.dart';

void main() {
  testWidgets('AgriTrack smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AgriTrackApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

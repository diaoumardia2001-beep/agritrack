// test/widgets/health_status_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/widgets/health_status_badge.dart';

void main() {
  group('HealthStatusBadge Widget Tests', () {
    testWidgets('renders Sain badge with correct text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthStatusBadge(status: HealthStatus.sain),
          ),
        ),
      );

      expect(find.text('Sain'), findsOneWidget);
    });

    testWidgets('renders À surveiller badge with correct text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthStatusBadge(status: HealthStatus.aSurveiller),
          ),
        ),
      );

      expect(find.text('À surveiller'), findsOneWidget);
    });

    testWidgets('renders Malade badge with correct text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthStatusBadge(status: HealthStatus.malade),
          ),
        ),
      );

      expect(find.text('Malade'), findsOneWidget);
    });
  });
}

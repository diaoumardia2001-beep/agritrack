// test/widgets/design_system_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agritrack/theme/app_colors.dart';
import 'package:agritrack/theme/app_theme.dart';
import 'package:agritrack/widgets/agritrack_logo.dart';
import 'package:agritrack/widgets/agri_card.dart';
import 'package:agritrack/widgets/agri_icon_container.dart';
import 'package:agritrack/widgets/agri_section_header.dart';
import 'package:agritrack/screens/main_shell.dart';
import 'package:agritrack/models/animal.dart';

void main() {
  group('Design System - Theme & Colors', () {
    test('AppColors provides verified colors for species and health status',
        () {
      expect(AppColors.forSpecies(AnimalType.bovin), AppColors.speciesBovin);
      expect(AppColors.forSpecies(AnimalType.caprin), AppColors.speciesCaprin);
      expect(AppColors.forSpecies(AnimalType.ovin), AppColors.speciesOvin);
      expect(
          AppColors.forSpecies(AnimalType.volaille), AppColors.speciesVolaille);

      expect(AppColors.forHealthStatus(HealthStatus.sain, isDark: false),
          AppColors.healthGoodLight);
      expect(AppColors.forHealthStatus(HealthStatus.sain, isDark: true),
          AppColors.healthGoodDark);
      expect(AppColors.forHealthStatus(HealthStatus.malade, isDark: false),
          AppColors.healthCriticalLight);
    });

    test('AppTheme creates valid light and dark ThemeData', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
    });
  });

  group('Design System - Core Components', () {
    testWidgets('AgriTrackLogo renders standalone and with text',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AgriTrackLogo(size: 32),
                AgriTrackLogo(
                    size: 40,
                    showText: true,
                    subtitle: 'GESTION & SUIVI DE CHEPTEL'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AgriTrackLogo), findsNWidgets(2));
      expect(find.textContaining('Agri', findRichText: true), findsOneWidget);
      expect(find.textContaining('Track', findRichText: true), findsOneWidget);
      expect(find.text('GESTION & SUIVI DE CHEPTEL'), findsOneWidget);
    });

    testWidgets('AgriCard renders content and handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgriCard(
              onTap: () => tapped = true,
              child: const Text('Carte Test'),
            ),
          ),
        ),
      );

      expect(find.text('Carte Test'), findsOneWidget);
      await tester.tap(find.text('Carte Test'));
      expect(tapped, isTrue);
    });

    testWidgets('AgriIconContainer renders icon with correct container',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AgriIconContainer(
              icon: Icons.eco,
              color: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.eco), findsOneWidget);
    });

    testWidgets('AgriSectionHeader displays title, subtitle and action',
        (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgriSectionHeader(
              title: 'Mes Statistiques',
              subtitle: 'Aperçu du mois',
              trailingLabel: 'Voir détails',
              onTrailingTap: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Mes Statistiques'), findsOneWidget);
      expect(find.text('Aperçu du mois'), findsOneWidget);
      expect(find.text('Voir détails'), findsOneWidget);

      await tester.tap(find.text('Voir détails'));
      expect(actionTapped, isTrue);
    });
  });

  group('Design System - Responsive MainShell Navigation', () {
    testWidgets(
        'Renders Mobile layout with bottom bar on narrow screens (<768px)',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MainShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tableau'), findsOneWidget);
      expect(find.text('Cheptel'), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.byType(BottomAppBar), findsOneWidget);
    });

    testWidgets('Renders Desktop layout with Sidebar on wide screens (>=768px)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MainShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AgriTrackLogo), findsWidgets);
      expect(find.text('Agri'), findsWidgets);
      expect(find.text('Track'), findsWidgets);
      expect(find.text('.'), findsWidgets);
      expect(find.text('GESTION & SUIVI DE CHEPTEL'), findsWidgets);
      expect(find.text('Tableau'), findsOneWidget);
      expect(find.text('Cheptel'), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Exploitation active'), findsOneWidget);
      expect(find.byType(BottomAppBar), findsNothing);
    });

    testWidgets(
        'Renders Tablet layout with compact AgriTrackLogo on medium screens (768px-1023px)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MainShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AgriTrackLogo), findsWidgets);
      expect(find.text('Agri'), findsWidgets);
      expect(find.text('Track'), findsWidgets);
      expect(find.text('.'), findsWidgets);
      expect(find.text('Tableau'), findsOneWidget);
      expect(find.text('Cheptel'), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Exploitation active'), findsOneWidget);
      expect(find.byType(BottomAppBar), findsNothing);
    });
  });
}

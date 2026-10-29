// test/widgets/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agritrack/providers/locale_provider.dart';
import 'package:agritrack/providers/shared_preferences_provider.dart';
import 'package:agritrack/providers/theme_provider.dart';
import 'package:agritrack/screens/settings_screen.dart';
import 'package:agritrack/theme/app_theme.dart';

Widget _buildSettingsApp({
  required SharedPreferences prefs,
  ThemeData? theme,
  List<Override> additionalOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...additionalOverrides,
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─── Test 1 : Rendu complet de l'écran des paramètres ──────────────────────
  testWidgets(
      '1. Rendu complet de l\'écran des paramètres (en-tête, sections, cartes)',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildSettingsApp(prefs: prefs));
    await tester.pumpAndSettle();

    // En-tête
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Paramètres & Préférences'), findsOneWidget);
    expect(
      find.text(
          'Personnalisez l\'affichage, la langue et consultez l\'état du stockage local.'),
      findsOneWidget,
    );

    // Sections
    expect(find.text('Apparence'), findsOneWidget);
    expect(find.text('Thème'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Langue de l\'application'), findsOneWidget);
    expect(find.text('Stockage & Données locales'), findsOneWidget);
    expect(find.text('AgriTrack'), findsWidgets);
  });

  // ─── Test 2 : Sélection du thème clair ────────────────────────────────────
  testWidgets('2. Sélection du thème clair via l\'option dédiée',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({themePreferenceKey: 'dark'});
    final prefs = await SharedPreferences.getInstance();

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            return const MaterialApp(home: SettingsScreen());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lightOption = find.byKey(const ValueKey('theme_option_light'));
    expect(lightOption, findsOneWidget);

    await tester.ensureVisible(lightOption);
    await tester.tap(lightOption);
    await tester.pumpAndSettle();

    expect(capturedRef.read(themeModeProvider), ThemeMode.light);
    expect(prefs.getString(themePreferenceKey), 'light');
  });

  // ─── Test 3 : Sélection du thème sombre via option et Switch ──────────────
  testWidgets(
      '3. Sélection du thème sombre via l\'option dédiée et via le Switch rapide',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({themePreferenceKey: 'light'});
    final prefs = await SharedPreferences.getInstance();

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            return const MaterialApp(home: SettingsScreen());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sélection via le bouton d'option Sombre
    final darkOption = find.byKey(const ValueKey('theme_option_dark'));
    expect(darkOption, findsOneWidget);

    await tester.ensureVisible(darkOption);
    await tester.tap(darkOption);
    await tester.pumpAndSettle();

    expect(capturedRef.read(themeModeProvider), ThemeMode.dark);
    expect(prefs.getString(themePreferenceKey), 'dark');

    // Bascule rapide via le Switch
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(capturedRef.read(themeModeProvider), ThemeMode.light);
    expect(prefs.getString(themePreferenceKey), 'light');
  });

  // ─── Test 4 : Sélection du thème système ──────────────────────────────────
  testWidgets('4. Sélection du thème système via l\'option dédiée',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            return const MaterialApp(home: SettingsScreen());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final systemOption = find.byKey(const ValueKey('theme_option_system'));
    expect(systemOption, findsOneWidget);

    await tester.ensureVisible(systemOption);
    await tester.tap(systemOption);
    await tester.pumpAndSettle();

    expect(capturedRef.read(themeModeProvider), ThemeMode.system);
    expect(prefs.getString(themePreferenceKey), 'system');
  });

  // ─── Test 5 : Persistance du thème dans SharedPreferences ─────────────────
  testWidgets('5. Persistance et restauration du thème au redémarrage',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({themePreferenceKey: 'dark'});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    // Doit restaurer directement ThemeMode.dark
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // Modification vers système
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.system);
    expect(prefs.getString(themePreferenceKey), 'system');

    // Deuxième container simulant un redémarrage
    final container2 = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    expect(container2.read(themeModeProvider), ThemeMode.system);
  });

  // ─── Test 6 : Langues prises en charge & statuts de couverture ─────────────
  testWidgets(
      '6. Affichage des langues réellement prises en charge et statuts honnêtes',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildSettingsApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Français principal
    expect(find.text('Français (Côte d\'Ivoire)'), findsWidgets);
    expect(find.text('Complète'), findsOneWidget);

    // Anglais partiel
    expect(find.text('English (US)'), findsWidgets);
    expect(find.text('Partielle'), findsOneWidget);

    // Langues ivoiriennes à venir
    expect(find.text('Langues locales ivoiriennes'), findsOneWidget);
    expect(find.text('Bientôt'), findsOneWidget);

    // Note sur la rédaction native en français et les FCFA
    expect(
      find.text(
          'AgriTrack est rédigé nativement en français ivoirien. Les termes techniques et calculs monétaires (FCFA) respectent les usages locaux.'),
      findsOneWidget,
    );
  });

  // ─── Test 7 : Sélection et persistance de la langue ───────────────────────
  testWidgets('7. Sélection de langue via dialogue et persistance du choix',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildSettingsApp(prefs: prefs));
    await tester.pumpAndSettle();

    final changerBtn = find.text('Changer');
    expect(changerBtn, findsOneWidget);
    await tester.ensureVisible(changerBtn);
    await tester.tap(changerBtn);
    await tester.pumpAndSettle();

    expect(find.text('Choisir la langue'), findsOneWidget);
    expect(find.text('🇺🇸 English (US)'), findsOneWidget);

    await tester.tap(find.text('🇺🇸 English (US)'));
    await tester.pumpAndSettle();

    // Persistance dans SharedPreferences
    expect(prefs.getString(localePreferenceKey), 'en_US');

    // L'en-tête s'est mis à jour vers l'anglais
    expect(find.text('Settings'), findsOneWidget);
  });

  // ─── Test 8 : Affichage correct de la version et technologies ─────────────
  testWidgets('8. Affichage de la version 1.0.0 et des technologies réelles',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildSettingsApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('v1.0.0'), findsOneWidget);
    expect(
      find.text('Version 1.0.0 • Fait avec ❤️ pour les éleveurs CI'),
      findsOneWidget,
    );

    // Technologies réellement utilisées
    expect(find.text('Flutter & Dart'), findsOneWidget);
    expect(find.text('Material 3'), findsOneWidget);
    expect(find.text('Riverpod'), findsOneWidget);
    expect(find.text('Sembast NoSQL'), findsOneWidget);
    expect(find.text('SharedPreferences'), findsOneWidget);
  });

  // ─── Test 9 : Données locales & absence de suppression involontaire ────────
  testWidgets(
      '9. Politique de stockage local Sembast et absence de suppression destructrice',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_buildSettingsApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Informations d'architecture locale
    expect(find.text('Sembast NoSQL Local'), findsOneWidget);
    expect(find.text('100% Hors-ligne (Offline-First)'), findsOneWidget);
    expect(find.text('Aucune transmission cloud'), findsOneWidget);

    // Note de protection empêchant la perte de données
    expect(
      find.text(
          'Protection de vos données : Pour prévenir toute perte involontaire d\'animaux ou de dépenses, la réinitialisation sélective sera introduite avec export sécurisé.'),
      findsOneWidget,
    );

    // Aucun bouton destructeur non sécurisé ne doit être présent
    expect(find.text('Effacer la base'), findsNothing);
    expect(find.text('Supprimer toutes les données'), findsNothing);
    expect(find.text('Réinitialiser la base'), findsNothing);
  });

  // ─── Test 10 : Rendu en thèmes clair et sombre sans débordement ───────────
  testWidgets(
      '10. Fonctionnement et rendu sans débordement en clair et en sombre',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Rendu en mode Clair
    await tester.pumpWidget(
      _buildSettingsApp(prefs: prefs, theme: AppTheme.lightTheme),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Rendu en mode Sombre
    await tester.pumpWidget(
      _buildSettingsApp(prefs: prefs, theme: AppTheme.darkTheme),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

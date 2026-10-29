// test/unit/preferences_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agritrack/providers/locale_provider.dart';
import 'package:agritrack/providers/shared_preferences_provider.dart';
import 'package:agritrack/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeMode Persistence', () {
    test('1. Default theme is ThemeMode.light when no preference exists',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, ThemeMode.light);
    });

    test('2. Restores saved dark theme from SharedPreferences synchronously',
        () async {
      SharedPreferences.setMockInitialValues({themePreferenceKey: 'dark'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, ThemeMode.dark);
    });

    test('2b. Restores saved light theme from SharedPreferences synchronously',
        () async {
      SharedPreferences.setMockInitialValues({themePreferenceKey: 'light'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, ThemeMode.light);
    });

    test('3. Saves new theme mode when toggled or explicitly set', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, ThemeMode.light);

      await notifier.toggle();
      expect(notifier.state, ThemeMode.dark);
      expect(prefs.getString(themePreferenceKey), 'dark');

      await notifier.setMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);
      expect(prefs.getString(themePreferenceKey), 'light');
    });

    test('4. Safe fallback to ThemeMode.light when stored value is invalid',
        () async {
      SharedPreferences.setMockInitialValues(
          {themePreferenceKey: 'invalid_theme_value'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, ThemeMode.light);
    });

    test('5. Read error handling: returns ThemeMode.light on type mismatch',
        () async {
      SharedPreferences.setMockInitialValues({themePreferenceKey: 99999});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeModeNotifier(prefs);
      expect(notifier.state, ThemeMode.light);
    });

    test('6. User interaction before async loading finishes is preserved',
        () async {
      SharedPreferences.setMockInitialValues({themePreferenceKey: 'dark'});

      // Instantiate with null prefs to trigger async loading in background
      final notifier = ThemeModeNotifier(null);
      // User immediately chooses light mode before async load completes
      await notifier.setMode(ThemeMode.light);

      // Wait for any async tasks to resolve
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, ThemeMode.light);
    });

    test(
        '7. Riverpod provider correctly reads pre-loaded SharedPreferences override synchronously',
        () async {
      SharedPreferences.setMockInitialValues({themePreferenceKey: 'dark'});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('Locale Persistence', () {
    test('1. Default locale is fr_CI when no preference exists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      expect(notifier.state, const Locale('fr', 'CI'));
    });

    test('2. Restores saved en_US locale from SharedPreferences synchronously',
        () async {
      SharedPreferences.setMockInitialValues({localePreferenceKey: 'en_US'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      expect(notifier.state, const Locale('en', 'US'));
    });

    test('2b. Restores saved fr_CI locale from SharedPreferences synchronously',
        () async {
      SharedPreferences.setMockInitialValues({localePreferenceKey: 'fr_CI'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      expect(notifier.state, const Locale('fr', 'CI'));
    });

    test('3. Saves new locale when toggled or setLocale is called', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      expect(notifier.state, const Locale('fr', 'CI'));

      await notifier.toggleLocale();
      expect(notifier.state, const Locale('en', 'US'));
      expect(prefs.getString(localePreferenceKey), 'en_US');

      await notifier.setLocale(const Locale('fr', 'CI'));
      expect(notifier.state, const Locale('fr', 'CI'));
      expect(prefs.getString(localePreferenceKey), 'fr_CI');
    });

    test('4. Safe fallback to fr_CI when stored locale is unsupported',
        () async {
      SharedPreferences.setMockInitialValues({localePreferenceKey: 'es_ES'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      expect(notifier.state, const Locale('fr', 'CI'));
    });

    test('5. Safe fallback to fr_CI when stored locale is malformed or empty',
        () async {
      SharedPreferences.setMockInitialValues({localePreferenceKey: '   '});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      expect(notifier.state, const Locale('fr', 'CI'));
    });

    test('6. Read error handling: returns fr_CI on type mismatch', () async {
      SharedPreferences.setMockInitialValues({localePreferenceKey: 12345});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      expect(notifier.state, const Locale('fr', 'CI'));
    });

    test('7. Setting an unsupported locale falls back to default fr_CI',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LocaleNotifier(prefs);
      await notifier.setLocale(const Locale('de', 'DE'));
      expect(notifier.state, const Locale('fr', 'CI'));
    });

    test('8. User interaction before async loading finishes is preserved',
        () async {
      SharedPreferences.setMockInitialValues({localePreferenceKey: 'en_US'});

      // Instantiate with null prefs to trigger async loading in background
      final notifier = LocaleNotifier(null);
      // User explicitly sets fr_CI
      await notifier.setLocale(const Locale('fr', 'CI'));

      // Wait for any async tasks to resolve
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, const Locale('fr', 'CI'));
    });

    test(
        '9. Riverpod provider correctly reads pre-loaded SharedPreferences override synchronously',
        () async {
      SharedPreferences.setMockInitialValues({localePreferenceKey: 'en_US'});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(localeProvider), const Locale('en', 'US'));
    });
  });
}

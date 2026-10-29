// lib/providers/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences_provider.dart';

/// SharedPreferences key for persisting the chosen locale.
const String localePreferenceKey = 'agritrack_locale';

/// Default application locale: French (Côte d'Ivoire).
const Locale defaultLocale = Locale('fr', 'CI');

class LocaleNotifier extends StateNotifier<Locale> {
  SharedPreferences? _prefs;
  bool _userHasChangedState = false;

  LocaleNotifier([this._prefs]) : super(_initialLocale(_prefs)) {
    if (_prefs == null) {
      _loadFromPrefsAsync();
    }
  }

  static Locale _initialLocale(SharedPreferences? prefs) {
    if (prefs == null) return defaultLocale;
    try {
      final raw = prefs.getString(localePreferenceKey);
      return parseSupportedLocale(raw);
    } catch (_) {
      return defaultLocale;
    }
  }

  /// Parses a persisted string into a supported [Locale] with fallback to [defaultLocale].
  static Locale parseSupportedLocale(String? value) {
    if (value == null || value.trim().isEmpty) {
      return defaultLocale;
    }
    final normalized = value.trim().replaceAll('-', '_').toLowerCase();
    if (normalized == 'fr_ci' || normalized == 'fr') {
      return const Locale('fr', 'CI');
    }
    if (normalized == 'en_us' || normalized == 'en') {
      return const Locale('en', 'US');
    }
    if (normalized.startsWith('fr')) {
      return const Locale('fr', 'CI');
    }
    if (normalized.startsWith('en')) {
      return const Locale('en', 'US');
    }
    return defaultLocale;
  }

  /// Returns true if the language is supported by AgriTrack (fr or en).
  static bool isSupported(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    return lang == 'fr' || lang == 'en';
  }

  Future<void> _loadFromPrefsAsync() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final p = await SharedPreferences.getInstance();
      _prefs ??= p;
      if (!_userHasChangedState) {
        final raw = p.getString(localePreferenceKey);
        if (!_userHasChangedState && raw != null) {
          state = parseSupportedLocale(raw);
        }
      }
    } catch (_) {
      // Gracefully maintain current state on storage error
    }
  }

  Future<void> setLocale(Locale locale) async {
    _userHasChangedState = true;
    Locale target;
    if (locale.languageCode == 'fr') {
      target = locale.countryCode != null && locale.countryCode!.isNotEmpty
          ? locale
          : const Locale('fr', 'CI');
    } else if (locale.languageCode == 'en') {
      target = locale.countryCode != null && locale.countryCode!.isNotEmpty
          ? locale
          : const Locale('en', 'US');
    } else {
      target = defaultLocale;
    }
    state = target;
    await _persistLocale(target);
  }

  Future<void> toggleLocale() async {
    _userHasChangedState = true;
    if (state.languageCode == 'fr') {
      state = const Locale('en', 'US');
    } else {
      state = const Locale('fr', 'CI');
    }
    await _persistLocale(state);
  }

  Future<void> _persistLocale(Locale loc) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final p = _prefs ?? await SharedPreferences.getInstance();
      _prefs = p;
      final code = loc.countryCode != null && loc.countryCode!.isNotEmpty
          ? '${loc.languageCode}_${loc.countryCode}'
          : loc.languageCode;
      await p.setString(localePreferenceKey, code);
    } catch (e) {
      debugPrint('Error saving locale preference: $e');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});

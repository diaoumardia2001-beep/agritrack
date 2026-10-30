// lib/core/demo_mode_config.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service de configuration et de détection du Mode Démonstration pour AgriTrack.
///
/// Le mode démo permet aux visiteurs (notamment les recruteurs) d'essayer
/// l'ensemble des fonctionnalités interactives (ajout, modification, suppression,
/// dépenses, filtres, tri) sur une base de données isolée en mémoire vive,
/// sans compte utilisateur et avec une garantie absolue d'absence d'écriture
/// vers Supabase ou la base persistante locale.
class DemoModeConfig {
  static bool? _overrideForTesting;

  /// Permet de forcer l'état du mode démo pour les tests unitaires et widgets.
  static void setOverrideForTesting(bool? value) {
    _overrideForTesting = value;
  }

  /// Détermine si le mode démonstration est activé via l'URL (`?demo=true`)
  /// ou via un forçage explicite pour les tests.
  ///
  /// Par défaut et en l'absence de paramètre explicite, retourne toujours `false`.
  static bool isDemoMode([Uri? currentUri]) {
    if (_overrideForTesting != null) {
      return _overrideForTesting!;
    }

    try {
      final uri = currentUri ?? (kIsWeb ? Uri.base : null);
      if (uri != null) {
        final demoParam = uri.queryParameters['demo']?.trim().toLowerCase();
        return demoParam == 'true' || demoParam == '1';
      }
    } catch (_) {
      // En cas d'erreur de parsing d'URL, sécurité par défaut : mode démo inactif
    }

    return false;
  }
}

/// Notifier Riverpod gérant l'état actif/inactif du mode démo.
class DemoModeNotifier extends StateNotifier<bool> {
  DemoModeNotifier({bool? initialValue})
      : super(initialValue ?? DemoModeConfig.isDemoMode());

  /// Active le mode démonstration
  void enableDemoMode() {
    state = true;
  }

  /// Désactive le mode démonstration
  void disableDemoMode() {
    state = false;
  }

  /// Bascule l'état du mode démonstration
  void toggleDemoMode() {
    state = !state;
  }
}

/// Provider global Riverpod exposant l'état du mode démo.
/// Inactif (`false`) par défaut sauf si `?demo=true` est détecté dans l'URL.
final isDemoModeProvider =
    StateNotifierProvider<DemoModeNotifier, bool>((ref) {
  return DemoModeNotifier();
});


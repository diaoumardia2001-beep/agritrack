// lib/widgets/account_app_bar_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/settings_screen.dart';
import '../theme/app_colors.dart';

/// Bouton d'accès discret au compte dans l'AppBar de l'écran principal.
///
/// Affiche :
/// - Les initiales de l'utilisateur (ou photo de profil si disponible) lorsqu'il est connecté.
/// - Une icône de compte neutre lorsqu'il est en mode local hors-ligne.
///
/// Au clic : ouvre la section « Mon compte » dans SettingsScreen ou déclenche [onTap].
class AccountAppBarButton extends ConsumerWidget {
  final VoidCallback? onTap;

  const AccountAppBarButton({
    super.key,
    this.onTap,
  });

  /// Extrait des initiales lisibles (1 ou 2 lettres majuscules) à partir du nom ou email
  static String extractInitials(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'É';

    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (parts.length >= 2) {
      final first = parts[0].characters.first;
      final second = parts[1].characters.first;
      return '$first$second'.toUpperCase();
    }

    final single = parts[0];
    if (single.length >= 2 && !single.contains('@')) {
      return single.substring(0, 2).toUpperCase();
    }
    return single.characters.first.toUpperCase();
  }

  void _handleClick(BuildContext context) {
    if (onTap != null) {
      onTap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isAuthenticated = authState.isAuthenticated;
    final displayName = authState.displayName;
    final initials = extractInitials(displayName);

    // Détection d'une URL de photo de profil fiable dans les métadonnées
    final avatarUrl = authState.user?.userMetadata?['avatar_url'] as String?;
    final hasValidAvatarUrl = avatarUrl != null &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    final tooltip = isAuthenticated
        ? '$displayName (Compte connecté)'
        : 'Mon compte (Mode local)';

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('app_bar_account_button'),
          onTap: () => _handleClick(context),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAuthenticated
                    ? theme.colorScheme.primary
                        .withValues(alpha: isDark ? 0.25 : 0.12)
                    : (isDark
                        ? AppColors.darkSurfaceSubtle
                        : AppColors.lightSurfaceSubtle),
                border: Border.all(
                  color: isAuthenticated
                      ? theme.colorScheme.primary
                          .withValues(alpha: isDark ? 0.6 : 0.35)
                      : (isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder),
                  width: isAuthenticated ? 1.5 : 1.0,
                ),
              ),
              child: Center(
                child: isAuthenticated
                    ? (hasValidAvatarUrl
                        ? ClipOval(
                            child: Image.network(
                              avatarUrl,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildInitialsText(theme, initials),
                            ),
                          )
                        : _buildInitialsText(theme, initials))
                    : Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsText(ThemeData theme, String initials) {
    return Text(
      initials,
      key: const ValueKey('app_bar_account_initials'),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

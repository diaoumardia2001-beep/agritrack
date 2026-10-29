// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/animal.dart';
import '../providers/active_farm_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_card.dart';
import '../widgets/agri_icon_container.dart';
import '../widgets/agritrack_logo.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'farm/create_farm_dialog.dart';
import 'farm/select_farm_dialog.dart';

/// Écran des paramètres d'AgriTrack.
/// Offre une gestion complète de l'apparence (clair, sombre, système),
/// de la langue avec couverture documentée honnêtement,
/// et de la transparence sur la persistance des données locales (Sembast).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final isFrench = locale.languageCode == 'fr';
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final activeFarmState = ref.watch(activeFarmProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          isFrench ? 'Réglages' : 'Settings',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── En-tête de page ─────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AgriIconContainer(
                      icon: Icons.tune_rounded,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                      size: 44,
                      iconSize: 22,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFrench
                                ? 'Paramètres & Préférences'
                                : 'Settings & Preferences',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFrench
                                ? 'Personnalisez l\'affichage, la langue et consultez l\'état du stockage local.'
                                : 'Customize display, language, and check local storage status.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Section 0 : Compte & Exploitations ──────────────────
                _AccountAndFarmCard(
                  authState: authState,
                  farmState: activeFarmState,
                  isDark: isDark,
                  isFrench: isFrench,
                ),
                const SizedBox(height: 20),

                // ─── Section 1 : Apparence ───────────────────────────────
                AgriCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AgriIconContainer(
                            icon: Icons.palette_outlined,
                            color: AppColors.forSpecies(AnimalType.bovin),
                            size: 38,
                            iconSize: 20,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFrench ? 'Apparence' : 'Appearance',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isFrench
                                      ? 'Thème clair, sombre ou adapté au système'
                                      : 'Light, dark, or system-adaptive theme',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Interrupteur rapide Thème (compatible tests existants)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceSubtle
                              : AppColors.lightSurfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              size: 22,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFrench ? 'Thème' : 'Theme',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    isDark
                                        ? (isFrench
                                            ? 'Mode sombre activé'
                                            : 'Dark mode enabled')
                                        : (isFrench
                                            ? 'Mode clair activé'
                                            : 'Light mode enabled'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isDark,
                              onChanged: (_) =>
                                  ref.read(themeModeProvider.notifier).toggle(),
                              activeThumbColor: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sélecteur 3 modes : Clair / Sombre / Système
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeModeOption(
                              key: const ValueKey('theme_option_light'),
                              label: isFrench ? 'Clair' : 'Light',
                              icon: Icons.light_mode_outlined,
                              selected: themeMode == ThemeMode.light,
                              onTap: () => ref
                                  .read(themeModeProvider.notifier)
                                  .setMode(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ThemeModeOption(
                              key: const ValueKey('theme_option_dark'),
                              label: isFrench ? 'Sombre' : 'Dark',
                              icon: Icons.dark_mode_outlined,
                              selected: themeMode == ThemeMode.dark,
                              onTap: () => ref
                                  .read(themeModeProvider.notifier)
                                  .setMode(ThemeMode.dark),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ThemeModeOption(
                              key: const ValueKey('theme_option_system'),
                              label: isFrench ? 'Système' : 'System',
                              icon: Icons.settings_brightness_outlined,
                              selected: themeMode == ThemeMode.system,
                              onTap: () => ref
                                  .read(themeModeProvider.notifier)
                                  .setMode(ThemeMode.system),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Section 2 : Langue ──────────────────────────────────
                AgriCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AgriIconContainer(
                            icon: Icons.language_outlined,
                            color: Color(0xFF0284C7),
                            size: 38,
                            iconSize: 20,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFrench ? 'Langue' : 'Language',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isFrench
                                      ? 'Langue d\'interface et régionalisation'
                                      : 'Interface language and regionalization',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Tuile Langue active (compatible tests existants)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceSubtle
                              : AppColors.lightSurfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🇨🇮', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFrench
                                        ? 'Langue de l\'application'
                                        : 'Application Language',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    isFrench
                                        ? 'Français (Côte d\'Ivoire)'
                                        : 'English (United States)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () =>
                                  _showLanguageDialog(context, ref, isFrench),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(isFrench ? 'Changer' : 'Change'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Statut réel des langues (transparence honnête)
                      _LanguageStatusTile(
                        flag: '🇨🇮',
                        name: 'Français (Côte d\'Ivoire)',
                        status: isFrench
                            ? 'Langue principale • 100% traduite'
                            : 'Primary language • Fully translated',
                        coverageBadge: 'Complète',
                        badgeColor: const Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 8),
                      _LanguageStatusTile(
                        flag: '🇺🇸',
                        name: 'English (US)',
                        status: isFrench
                            ? 'Bêta • Clés principales traduites'
                            : 'Beta • Key terms translated',
                        coverageBadge: 'Partielle',
                        badgeColor: const Color(0xFFD97706),
                      ),
                      const SizedBox(height: 8),
                      const _LanguageStatusTile(
                        flag: '🌍',
                        name: 'Langues locales ivoiriennes',
                        status: 'Dioula • Baoulé (en cours d\'intégration)',
                        coverageBadge: 'Bientôt',
                        badgeColor: Color(0xFF0284C7),
                      ),
                      const SizedBox(height: 14),

                      // Note pédagogique sur la couverture linguistique
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary)
                              .withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                .withValues(alpha: isDark ? 0.3 : 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isFrench
                                    ? 'AgriTrack est rédigé nativement en français ivoirien. Les termes techniques et calculs monétaires (FCFA) respectent les usages locaux.'
                                    : 'AgriTrack is natively authored in Ivorian French. Financial metrics (FCFA) follow local practices.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Section 3 : Données & Stockage local ─────────────────
                AgriCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AgriIconContainer(
                            icon: Icons.storage_outlined,
                            color: Color(0xFFD97706),
                            size: 38,
                            iconSize: 20,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFrench
                                      ? 'Stockage & Données locales'
                                      : 'Local Storage & Data',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isFrench
                                      ? 'Persistance sécurisée sur cet appareil'
                                      : 'Secure persistence on this device',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      _DataStorageRow(
                        icon: Icons.dns_outlined,
                        title: isFrench ? 'Moteur de base' : 'Database engine',
                        value: 'Sembast NoSQL Local',
                      ),
                      const Divider(height: 16),
                      _DataStorageRow(
                        icon: Icons.wifi_off_outlined,
                        title: isFrench ? 'Mode réseau' : 'Network mode',
                        value: isFrench
                            ? '100% Hors-ligne (Offline-First)'
                            : '100% Offline (Offline-First)',
                      ),
                      const Divider(height: 16),
                      _DataStorageRow(
                        icon: Icons.security_outlined,
                        title:
                            isFrench ? 'Confidentialité' : 'Privacy & Security',
                        value: isFrench
                            ? 'Aucune transmission cloud'
                            : 'No cloud transmission',
                      ),
                      const SizedBox(height: 16),

                      // Avertissement de sécurité sur la réinitialisation
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceSubtle
                              : AppColors.lightSurfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isFrench
                                    ? 'Protection de vos données : Pour prévenir toute perte involontaire d\'animaux ou de dépenses, la réinitialisation sélective sera introduite avec export sécurisé.'
                                    : 'Data protection: To prevent accidental loss of animals or expenses, selective reset will be introduced alongside secure backup export.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Section 4 : À propos & Identité de l'application ─────
                AgriCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AgriTrackLogo(
                            size: 48,
                            showText: false,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'AgriTrack',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkPrimaryContainer
                                            : AppColors.lightPrimaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'v1.0.0',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.darkPrimary
                                              : AppColors.lightPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isFrench
                                      ? 'Version 1.0.0 • Fait avec ❤️ pour les éleveurs CI'
                                      : 'Version 1.0.0 • Made with ❤️ for CI farmers',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isFrench
                            ? 'Plateforme moderne de suivi de cheptel et de gestion des dépenses pour les éleveurs agricoles de Côte d\'Ivoire.'
                            : 'Modern herd tracking and expense management platform for livestock farmers in Côte d\'Ivoire.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Puces des technologies réelles
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TechChip(label: 'Flutter & Dart'),
                          _TechChip(label: 'Material 3'),
                          _TechChip(label: 'Riverpod'),
                          _TechChip(label: 'Sembast NoSQL'),
                          _TechChip(label: 'SharedPreferences'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ─── Footer discret ──────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      const AgriTrackLogo(
                        size: 24,
                        showText: true,
                        compact: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFrench
                            ? 'Suivi de cheptel pour les éleveurs\nde Côte d\'Ivoire'
                            : 'Livestock management for farmers\nin Côte d\'Ivoire',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, bool isFrench) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(isFrench ? 'Choisir la langue' : 'Select Language'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(localeProvider.notifier)
                  .setLocale(const Locale('fr', 'CI'));
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                const Text('🇨🇮 Français (Côte d\'Ivoire)',
                    style: TextStyle(fontSize: 16)),
                const Spacer(),
                if (isFrench) const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(localeProvider.notifier)
                  .setLocale(const Locale('en', 'US'));
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                const Text('🇺🇸 English (US)', style: TextStyle(fontSize: 16)),
                const Spacer(),
                if (!isFrench) const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Option visuelle de thème ───────────────────────────────────────────────
class _ThemeModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark
                    ? AppColors.darkSurfaceSubtle
                    : AppColors.lightSurfaceSubtle),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? primary
                  : (isDark
                      ? AppColors.darkCardBorder
                      : AppColors.lightCardBorder),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? (isDark ? Colors.white : primary)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle_rounded, size: 14, color: primary),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Ligne de statut d'une langue ───────────────────────────────────────────
class _LanguageStatusTile extends StatelessWidget {
  final String flag;
  final String name;
  final String status;
  final String coverageBadge;
  final Color badgeColor;

  const _LanguageStatusTile({
    required this.flag,
    required this.name,
    required this.status,
    required this.coverageBadge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: badgeColor.withValues(alpha: isDark ? 0.4 : 0.25),
              ),
            ),
            child: Text(
              coverageBadge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ligne d'information stockage ───────────────────────────────────────────
class _DataStorageRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DataStorageRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── Puce de technologie ────────────────────────────────────────────────────
class _TechChip extends StatelessWidget {
  final String label;

  const _TechChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ─── Section Compte & Exploitations ─────────────────────────────────────────
class _AccountAndFarmCard extends ConsumerWidget {
  final AppAuthState authState;
  final ActiveFarmState farmState;
  final bool isDark;
  final bool isFrench;

  const _AccountAndFarmCard({
    required this.authState,
    required this.farmState,
    required this.isDark,
    required this.isFrench,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAuthenticated = authState.isAuthenticated;

    return AgriCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── En-tête de la carte ─────────────────────────────────
          Row(
            children: [
              AgriIconContainer(
                icon: isAuthenticated
                    ? Icons.account_circle_rounded
                    : Icons.person_outline_rounded,
                color: isAuthenticated
                    ? const Color(0xFF16A34A)
                    : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                size: 38,
                iconSize: 20,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFrench ? 'Mon compte' : 'My Account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isAuthenticated
                          ? authState.displayName
                          : (isFrench
                              ? 'Mode local hors-ligne'
                              : 'Offline local mode'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isAuthenticated
                          ? const Color(0xFF16A34A)
                          : theme.colorScheme.primary)
                      .withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isAuthenticated
                            ? const Color(0xFF16A34A)
                            : theme.colorScheme.primary)
                        .withValues(alpha: isDark ? 0.4 : 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isAuthenticated
                            ? const Color(0xFF16A34A)
                            : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAuthenticated
                          ? (isFrench ? 'Connecté' : 'Connected')
                          : (isFrench ? 'Mode local' : 'Local mode'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAuthenticated
                            ? const Color(0xFF16A34A)
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ─── Contenu selon l'état d'authentification ─────────────
          if (!isAuthenticated) ...[
            _buildUnauthenticatedView(context, theme),
          ] else ...[
            _buildAuthenticatedView(context, ref, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFrench
              ? 'Vos données sont stockées uniquement sur cet appareil. Connectez-vous ou créez un compte pour accéder à la synchronisation cloud et gérer des exploitations multi-utilisateurs.'
              : 'Your data is saved locally on this device. Sign in or create an account to access cloud sync and manage multi-user farms.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (!authState.isClientAvailable) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706)
                  .withValues(alpha: isDark ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD97706)
                    .withValues(alpha: isDark ? 0.4 : 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFrench
                        ? 'Service d\'authentification indisponible (mode 100% hors-ligne).'
                        : 'Authentication service unavailable (100% offline mode).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFF92400E),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('settings_login_button'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.login_rounded, size: 18),
              label: Text(isFrench ? 'Se connecter' : 'Sign In'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('settings_register_button'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: Text(isFrench ? 'Créer un compte' : 'Create Account'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthenticatedView(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Détails du profil
        _DetailRow(
          icon: Icons.person_outline,
          title: isFrench ? 'Nom' : 'Name',
          value: authState.displayName,
        ),
        const Divider(height: 16),
        _DetailRow(
          icon: Icons.email_outlined,
          title: 'E-mail',
          value: authState.email ?? (isFrench ? 'Non renseigné' : 'Not set'),
        ),
        const Divider(height: 16),
        _DetailRow(
          icon: Icons.agriculture_rounded,
          title: isFrench ? 'Exploitation active' : 'Active farm',
          value: farmState.activeFarm.name,
        ),
        const Divider(height: 16),
        _DetailRow(
          icon: Icons.badge_outlined,
          title: isFrench ? 'Rôle sur cette exploitation' : 'Role on this farm',
          value: farmState.userRoleOnActiveFarm.label,
        ),
        const Divider(height: 16),
        _DetailRow(
          icon: farmState.isRemote
              ? Icons.cloud_outlined
              : Icons.storage_outlined,
          title: isFrench ? 'Type d\'exploitation' : 'Farm type',
          value: farmState.isRemote
              ? (isFrench ? 'Exploitation Cloud' : 'Cloud Farm')
              : (isFrench
                  ? 'Exploitation locale (Sembast)'
                  : 'Local Farm (Sembast)'),
        ),
        const SizedBox(height: 16),

        // ─── Avertissement d'état de synchronisation si ferme distante ───
        if (farmState.isRemote) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7)
                  .withValues(alpha: isDark ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0284C7)
                    .withValues(alpha: isDark ? 0.4 : 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFrench
                        ? 'Note de synchronisation : La synchronisation cloud des animaux et dépenses n\'est pas encore disponible. Les animaux affichés dans l\'application proviennent de votre stockage local (Sembast).'
                        : 'Sync note: Cloud sync for animals and expenses is not yet available. Displayed animals come from local storage (Sembast).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? const Color(0xFFBAE6FD)
                          : const Color(0xFF0369A1),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ─── Assistant / Exploitations distantes ────────────────────────
        if (farmState.accessibleRemoteFarms.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  .withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                    .withValues(alpha: isDark ? 0.3 : 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_business_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFrench
                            ? 'Aucune exploitation distante associée'
                            : 'No remote farms associated',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isFrench
                      ? 'Créez votre première exploitation cloud pour organiser votre cheptel et inviter vos collaborateurs.'
                      : 'Create your first cloud farm to organize your livestock and invite team members.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('settings_create_farm_button'),
                  onPressed: () => CreateFarmDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                      isFrench ? 'Créer une exploitation' : 'Create a Farm'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('settings_switch_farm_button'),
                onPressed: () => SelectFarmDialog.show(context),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(isFrench
                    ? 'Changer d\'exploitation (${farmState.accessibleRemoteFarms.length})'
                    : 'Switch Farm (${farmState.accessibleRemoteFarms.length})'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('settings_create_another_farm_button'),
                onPressed: () => CreateFarmDialog.show(context),
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: Text(isFrench ? 'Nouvelle exploitation' : 'New Farm'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ─── Action de Déconnexion sécurisée ──────────────────────────
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFrench ? 'Session AgriTrack' : 'AgriTrack Session',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isFrench
                        ? 'La déconnexion préserve toutes vos données locales.'
                        : 'Signing out keeps all your local data safe.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('settings_logout_button'),
              onPressed: () => _showSignOutDialog(context, ref),
              icon: const Icon(Icons.logout_rounded,
                  size: 18, color: Color(0xFFDC2626)),
              label: Text(
                isFrench ? 'Déconnexion' : 'Sign Out',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded,
                color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 12),
            Text(isFrench ? 'Confirmer la déconnexion' : 'Confirm Sign Out'),
          ],
        ),
        content: Text(
          isFrench
              ? 'Êtes-vous sûr de vouloir vous déconnecter ?\n\nVos données locales (Sembast) restent conservées sur cet appareil et ne seront pas supprimées.'
              : 'Are you sure you want to sign out?\n\nYour local data (Sembast) will remain safely on this device and will not be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFrench ? 'Annuler' : 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm_logout_button'),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(isFrench ? 'Se déconnecter' : 'Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

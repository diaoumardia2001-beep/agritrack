// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final isFrench = locale.languageCode == 'fr';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFrench ? 'Réglages' : 'Settings',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Section Apparence ─────────────────────────────────────
          _SectionHeader(label: isFrench ? 'Apparence' : 'Appearance'),
          _SettingsTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: isFrench ? 'Thème' : 'Theme',
            subtitle: isDark
                ? (isFrench ? 'Mode sombre activé' : 'Dark mode enabled')
                : (isFrench ? 'Mode clair activé' : 'Light mode enabled'),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              activeThumbColor: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 16),

          // ─── Section Langue ────────────────────────────────────────
          _SectionHeader(label: isFrench ? 'Langue' : 'Language'),
          _SettingsTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.language,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: isFrench
                ? 'Langue de l\'application'
                : 'Application Language',
            subtitle: isFrench
                ? 'Français (Côte d\'Ivoire)'
                : 'English (United States)',
            trailing: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(isFrench ? 'Choisir la langue' : 'Select Language'),
                    children: [
                      SimpleDialogOption(
                        onPressed: () {
                          ref.read(localeProvider.notifier).setLocale(const Locale('fr', 'CI'));
                          Navigator.pop(ctx);
                        },
                        child: Row(
                          children: [
                            const Text('🇨🇮 Français (Côte d\'Ivoire)', style: TextStyle(fontSize: 16)),
                            if (isFrench) const Spacer(),
                            if (isFrench) const Icon(Icons.check, color: Colors.green),
                          ],
                        ),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          ref.read(localeProvider.notifier).setLocale(const Locale('en', 'US'));
                          Navigator.pop(ctx);
                        },
                        child: Row(
                          children: [
                            const Text('🇺🇸 English (US)', style: TextStyle(fontSize: 16)),
                            if (!isFrench) const Spacer(),
                            if (!isFrench) const Icon(Icons.check, color: Colors.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Text(isFrench ? 'Changer' : 'Change'),
            ),
          ),
          _SettingsTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.translate,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            title: 'Langues disponibles',
            subtitle: 'Français • Dioula • Baoulé (prochainement)',
            trailing: null,
          ),

          const SizedBox(height: 16),

          // ─── Section À propos ──────────────────────────────────────
          const _SectionHeader(label: 'À propos'),
          _SettingsTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🌿', style: TextStyle(fontSize: 22)),
            ),
            title: 'AgriTrack',
            subtitle: 'Version 1.0.0 • Fait avec ❤️ pour les éleveurs CI',
            trailing: null,
          ),
          _SettingsTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            title: 'Aide et support',
            subtitle: 'Documentation et contacts',
            trailing: const Icon(Icons.chevron_right),
          ),

          const SizedBox(height: 32),

          // ─── Footer ────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(
                  '🌿 AgriTrack',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Suivi de cheptel pour les éleveurs\nde Côte d\'Ivoire',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: leading,
        title: Text(
          title,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

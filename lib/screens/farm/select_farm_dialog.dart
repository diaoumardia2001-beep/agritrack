// lib/screens/farm/select_farm_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/active_farm_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/agri_icon_container.dart';
import 'create_farm_dialog.dart';

/// Dialogue permettant à un utilisateur connecté de basculer entre ses
/// exploitations autorisées (avec affichage précis du rôle sur chacune)
/// ou de revenir à l'exploitation locale Sembast.
class SelectFarmDialog extends ConsumerWidget {
  const SelectFarmDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SelectFarmDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final farmState = ref.watch(activeFarmProvider);

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: Row(
        children: [
          const AgriIconContainer(
            icon: Icons.swap_horiz_rounded,
            color: Color(0xFF0284C7),
            size: 38,
            iconSize: 22,
            borderRadius: 10,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Changer d\'exploitation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Sélectionnez l\'espace de travail actif',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Exploitations Distantes ───────────────────────────────
              if (farmState.accessibleRemoteFarms.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    'EXPLOITATIONS DISTANTES (CLOUD)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...farmState.accessibleRemoteFarms.map((membership) {
                  final isSelected =
                      farmState.activeFarm.id == membership.farm.id;
                  return _FarmTile(
                    key: ValueKey('farm_tile_${membership.farm.id}'),
                    name: membership.farm.name,
                    subtitle: membership.farm.region ?? 'Région non spécifiée',
                    roleBadge: membership.role.label,
                    roleColor: _colorForRole(membership.role),
                    icon: Icons.cloud_outlined,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(activeFarmProvider.notifier).selectFarm(
                            membership.farm,
                            role: membership.role,
                          );
                      Navigator.of(context).pop();
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],

              // ─── Exploitation Locale Sembast ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'STOCKAGE LOCAL (APPAREIL)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _FarmTile(
                key: const ValueKey('farm_tile_local'),
                name: farmState.localFarms.isNotEmpty
                    ? farmState.localFarms.first.name
                    : 'Exploitation locale (Sembast)',
                subtitle: 'Données stockées uniquement sur cet appareil',
                roleBadge: 'Local',
                roleColor: const Color(0xFF16A34A),
                icon: Icons.phone_android_rounded,
                isSelected: farmState.isLocal,
                onTap: () {
                  ref.read(activeFarmProvider.notifier).switchToLocalFarm();
                  Navigator.of(context).pop();
                },
              ),

              const SizedBox(height: 12),

              // ─── Bouton Créer une exploitation ─────────────────────────
              OutlinedButton.icon(
                key: const ValueKey('dialog_create_farm_button'),
                onPressed: () {
                  Navigator.of(context).pop();
                  CreateFarmDialog.show(context);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Créer une nouvelle exploitation'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('select_farm_close_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  static Color _colorForRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return const Color(0xFF16A34A);
      case UserRole.manager:
        return const Color(0xFF0284C7);
      case UserRole.worker:
        return const Color(0xFFD97706);
    }
  }
}

class _FarmTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String roleBadge;
  final Color roleColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FarmTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.roleBadge,
    required this.roleColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: isDark ? 0.2 : 0.08)
                  : (isDark
                      ? AppColors.darkSurfaceSubtle
                      : AppColors.lightSurfaceSubtle),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primary
                    : (isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color:
                      isSelected ? primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? primary : null,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: roleColor.withValues(alpha: isDark ? 0.4 : 0.25),
                    ),
                  ),
                  child: Text(
                    roleBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_rounded, size: 18, color: primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

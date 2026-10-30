// lib/widgets/demo_recruiter_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/animals_provider.dart';

/// Bandeau informatif et discret affiché en haut de l'application
/// lorsque le Mode Démonstration est activé (`?demo=true`).
///
/// Indique clairement aux recruteurs et visiteurs que les données sont
/// temporaires et propose un bouton de réinitialisation instantanée.
class DemoRecruiterBanner extends ConsumerWidget {
  const DemoRecruiterBanner({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restore_rounded, size: 32, color: Color(0xFF16A34A)),
        title: const Text(
          'Réinitialiser la démonstration ?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Toutes les modifications, ajouts et suppressions effectués durant votre session d\'essai seront effacés.\n\nLe cheptel initial (12 animaux et 25 dépenses de démonstration) sera immédiatement restauré.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(animalsNotifierProvider.notifier).resetDemoData();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF16A34A),
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Données de démonstration réinitialisées avec succès !',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade700,
              content: Text('Erreur lors de la réinitialisation : $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.35)
            : const Color(0xFFECFDF5),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF059669).withValues(alpha: 0.4)
                : const Color(0xFFA7F3D0),
            width: 1.0,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _buildBadge(isDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode démonstration — données fictives et temporaires',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildResetButton(context, ref, isDark),
                ),
              ],
            );
          }

          return Row(
            children: [
              _buildBadge(isDark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mode démonstration — données fictives et temporaires',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFF065F46),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildResetButton(context, ref, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF059669).withValues(alpha: 0.3)
            : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : const Color(0xFF34D399),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 13,
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
          ),
          const SizedBox(width: 4),
          Text(
            'DÉMO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    return OutlinedButton.icon(
      onPressed: () => _confirmReset(context, ref),
      icon: const Icon(Icons.restart_alt_rounded, size: 16),
      label: const Text(
        'Réinitialiser la démo',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF059669).withValues(alpha: 0.6)
              : const Color(0xFF10B981),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}


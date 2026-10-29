// lib/widgets/animal_card.dart
import 'package:flutter/material.dart';
import '../models/animal.dart';
import '../theme/app_colors.dart';
import 'agri_card.dart';
import 'health_status_badge.dart';
import 'species_avatar.dart';

class AnimalCard extends StatelessWidget {
  final Animal animal;
  final VoidCallback onTap;
  final bool isListView;

  const AnimalCard({
    super.key,
    required this.animal,
    required this.onTap,
    this.isListView = false,
  });

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label:
          'Animal ${animal.name}, ${animal.type.label}, santé ${animal.healthStatus.label}, poids ${animal.weightKg} kg, dépenses ${animal.totalExpenses.toStringAsFixed(0)} FCFA',
      button: true,
      child: AgriCard(
        onTap: onTap,
        padding: isListView
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
            : EdgeInsets.zero,
        borderRadius: 16,
        child: isListView
            ? _buildListLayout(theme, isDark)
            : _buildGridLayout(theme, isDark),
      ),
    );
  }

  static IconData _iconForSpecies(AnimalType type) {
    switch (type) {
      case AnimalType.bovin:
        return Icons.agriculture_rounded;
      case AnimalType.caprin:
        return Icons.terrain_rounded;
      case AnimalType.ovin:
        return Icons.filter_vintage_rounded;
      case AnimalType.volaille:
        return Icons.egg_rounded;
    }
  }

  Widget _buildPlaceholderBackground(bool isDark) {
    final color = AppColors.forSpecies(animal.type);
    return Container(
      color: color.withValues(alpha: isDark ? 0.25 : 0.15),
      child: Center(
        child: Icon(
          _iconForSpecies(animal.type),
          size: 48,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildImageBanner(ThemeData theme, bool isDark) {
    final effectivePath =
        (animal.imageUrl != null && animal.imageUrl!.trim().isNotEmpty)
            ? animal.imageUrl!.trim()
            : SpeciesAvatar.defaultAssetForSpecies(animal.type);
    final isNetwork = effectivePath.startsWith('http://') ||
        effectivePath.startsWith('https://');

    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo de l'animal avec cadrage professionnel et repli vectoriel
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: isNetwork
                ? Image.network(
                    effectivePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderBackground(isDark),
                  )
                : Image.asset(
                    effectivePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderBackground(isDark),
                  ),
          ),

          // Voile dégradé protecteur pour garantir la lisibilité des badges
          Container(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),

          // Badges en haut de la photo avec protection anti-débordement
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _iconForSpecies(animal.type),
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            animal.type.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: HealthStatusBadge(
                    status: animal.healthStatus,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridLayout(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── En-tête : Vraie photo représentative de l'animal ─────────
        _buildImageBanner(theme, isDark),

        // ─── Corps : Identité & Métriques physiques ───────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      animal.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Text(
                      'ID: ${animal.id}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Métriques : Poids, Âge et Dépenses
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.monitor_weight_outlined,
                    label: '${animal.weightKg}kg',
                  ),
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: '${animal.ageMonths}m',
                  ),
                  if (animal.totalExpenses > 0)
                    _InfoChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '${_formatAmount(animal.totalExpenses)} FCFA',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListLayout(ThemeData theme, bool isDark) {
    return Row(
      children: [
        SpeciesAvatar(
          type: animal.type,
          imageUrl: animal.imageUrl,
          size: 42,
          borderRadius: 12,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      animal.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      animal.type.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.forSpecies(animal.type),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _InfoChip(
                    icon: Icons.monitor_weight_outlined,
                    label: '${animal.weightKg}kg',
                  ),
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: '${animal.ageMonths}m',
                  ),
                  if (animal.totalExpenses > 0)
                    _InfoChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '${_formatAmount(animal.totalExpenses)} FCFA',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 0,
          child: HealthStatusBadge(
            status: animal.healthStatus,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurfaceVariant,
          size: 18,
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3.5),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

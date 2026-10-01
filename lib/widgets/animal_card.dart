// lib/widgets/animal_card.dart
import 'package:flutter/material.dart';
import '../models/animal.dart';
import 'health_status_badge.dart';

class AnimalCard extends StatelessWidget {
  final Animal animal;
  final VoidCallback onTap;

  const AnimalCard({
    super.key,
    required this.animal,
    required this.onTap,
  });

  Color _typeColor(AnimalType type) {
    switch (type) {
      case AnimalType.bovin:
        return const Color(0xFF5D4037);
      case AnimalType.caprin:
        return const Color(0xFF558B2F);
      case AnimalType.ovin:
        return const Color(0xFF1565C0);
      case AnimalType.volaille:
        return const Color(0xFFF57F17);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(animal.type);

    return Semantics(
      label: 'Animal ${animal.name}, ${animal.type.label}, santé ${animal.healthStatus.label}, poids ${animal.weightKg} kg',
      button: true,
      child: Card(
        elevation: 2,
        shadowColor: color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Emoji avatar ──────────────────────────────────────────
            Hero(
              tag: 'animal-avatar-${animal.id}',
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.8), color],
                  ),
                ),
                child: Center(
                  child: Text(
                    animal.type.emoji,
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
              ),
            ),
            // ─── Content ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          animal.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      HealthStatusBadge(
                        status: animal.healthStatus,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    animal.type.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.monitor_weight_outlined,
                        label: '${animal.weightKg}kg',
                      ),
                      const SizedBox(width: 6),
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: '${animal.ageMonths}m',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

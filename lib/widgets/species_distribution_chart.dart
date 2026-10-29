// lib/widgets/species_distribution_chart.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/animal.dart';
import '../theme/app_colors.dart';
import 'agri_card.dart';

/// Graphique en anneau (donut chart) présentant la répartition réelle du cheptel.
/// Rendu via CustomPainter natif, réactif au thème clair/sombre et accessible.
class SpeciesDistributionChart extends StatelessWidget {
  final Map<AnimalType, int> counts;

  const SpeciesDistributionChart({
    super.key,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = counts.values.fold<int>(0, (sum, count) => sum + count);

    return AgriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Répartition du cheptel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceSubtle
                      : AppColors.lightSurfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder,
                  ),
                ),
                child: Text(
                  '$total têtes',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (total == 0)
            _buildEmptyState(context, isDark)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 420;

                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            counts: counts,
                            total: total,
                            isDark: isDark,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$total',
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Total',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildLegend(context, total, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 130,
                          height: 130,
                          child: CustomPaint(
                            painter: _DonutChartPainter(
                              counts: counts,
                              total: total,
                              isDark: isDark,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$total',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Total',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLegend(context, total, isDark),
                    ],
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _EmptyDonutPainter(isDark: isDark),
                child: Center(
                  child: Icon(
                    Icons.pie_chart_outline_rounded,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun animal enregistré',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ajoutez votre premier animal pour voir la répartition.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, int total, bool isDark) {
    final theme = Theme.of(context);

    return Column(
      children: AnimalType.values.map((type) {
        final count = counts[type] ?? 0;
        final percentage = total > 0 ? (count / total * 100).round() : 0;
        final color = AppColors.forSpecies(type);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400,
                    color: count > 0
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '$count',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '$percentage%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<AnimalType, int> counts;
  final int total;
  final bool isDark;

  _DonutChartPainter({
    required this.counts,
    required this.total,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 16.0;

    if (total == 0) {
      final emptyPaint = Paint()
        ..color = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, emptyPaint);
      return;
    }

    // Calcul des espèces présentes (> 0)
    final presentSpecies =
        AnimalType.values.where((t) => (counts[t] ?? 0) > 0).toList();
    final hasMultiple = presentSpecies.length > 1;
    final gapAngle =
        hasMultiple ? (0.05 * 2 * math.pi / presentSpecies.length) : 0.0;
    final usableAngle =
        (2 * math.pi) - (hasMultiple ? gapAngle * presentSpecies.length : 0.0);

    double currentAngle = -math.pi / 2; // Démarrer en haut (12h)

    for (final type in presentSpecies) {
      final count = counts[type] ?? 0;
      final sweepAngle = (count / total) * usableAngle;
      final color = AppColors.forSpecies(type);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        currentAngle,
        sweepAngle,
        false,
        paint,
      );

      currentAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.counts != counts ||
        oldDelegate.total != total ||
        oldDelegate.isDark != isDark;
  }
}

class _EmptyDonutPainter extends CustomPainter {
  final bool isDark;

  _EmptyDonutPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 12.0;

    final paint = Paint()
      ..color = (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _EmptyDonutPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

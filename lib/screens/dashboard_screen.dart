// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/animal.dart';
import '../providers/animals_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/account_app_bar_button.dart';
import '../widgets/agri_card.dart';
import '../widgets/agri_icon_container.dart';
import '../widgets/agritrack_logo.dart';
import '../widgets/empty_state.dart';
import '../widgets/health_status_badge.dart';
import '../widgets/species_avatar.dart';
import '../widgets/species_distribution_chart.dart';
import 'add_animal_screen.dart';
import 'animal_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback? onNavigateToHerd;
  final VoidCallback? onNavigateToSettings;

  const DashboardScreen({
    super.key,
    this.onNavigateToHerd,
    this.onNavigateToSettings,
  });

  static const List<String> _frenchDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];
  static const List<String> _frenchMonths = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre'
  ];

  static String _formatFrenchDate(DateTime date) {
    final dayName = _frenchDays[date.weekday - 1];
    final dayNum = date.day;
    final monthName = _frenchMonths[date.month - 1];
    final year = date.year;
    return '$dayName $dayNum $monthName $year';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final animalsAsync = ref.watch(animalsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currencyFmt = NumberFormat.currency(
      locale: 'fr_CI',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    final capitalizedDate = _formatFrenchDate(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── En-tête AppBar SaaS ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 115,
            floating: false,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, right: 16, bottom: 8),
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AgriTrackLogo(
                      size: 20,
                      showText: true,
                      compact: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tableau de bord',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                          .withValues(alpha: isDark ? 0.15 : 0.08),
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip:
                    isDark ? 'Passer en mode clair' : 'Passer en mode sombre',
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
              ),
              AccountAppBarButton(
                onTap: onNavigateToSettings,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ─── Contenu principal ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Bandeau contextuel (date & état) ──
                      _ContextBanner(
                        dateString: capitalizedDate,
                        animalsCount: animalsAsync.valueOrNull?.length ?? 0,
                      ),
                      const SizedBox(height: 16),

                      // ── Cartes KPIs ──
                      animalsAsync.when(
                        loading: () => _buildKpiSkeleton(isDark),
                        error: (e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Erreur lors du calcul des statistiques : $e',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                        data: (animals) {
                          final stats = statsAsync.valueOrNull ??
                              DashboardStats(
                                totalAnimals: animals.length,
                                totalMonthlyExpenses: animals.fold(
                                    0, (sum, a) => sum + a.monthlyExpenses),
                                healthAlerts: animals
                                    .where((a) =>
                                        a.healthStatus ==
                                            HealthStatus.aSurveiller ||
                                        a.healthStatus == HealthStatus.malade)
                                    .length,
                              );

                          final totalWeight = animals.fold<double>(
                              0.0, (sum, a) => sum + a.weightKg);
                          final averageWeight = animals.isNotEmpty
                              ? (totalWeight / animals.length)
                              : 0.0;

                          return _KpiGrid(
                            stats: stats,
                            averageWeight: averageWeight,
                            totalWeight: totalWeight,
                            currencyFmt: currencyFmt,
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Disposition responsive : Activité + Répartition ──
                      animalsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (animals) {
                          final counts = <AnimalType, int>{
                            for (final type in AnimalType.values)
                              type: animals.where((a) => a.type == type).length,
                          };

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 800;

                              final recentSection = _buildRecentSection(
                                context,
                                animals: animals,
                                onNavigateToHerd: onNavigateToHerd,
                              );

                              final analyticsSection = Column(
                                children: [
                                  SpeciesDistributionChart(counts: counts),
                                  const SizedBox(height: 16),
                                  _QuickActionsCard(
                                    onNavigateToHerd: onNavigateToHerd,
                                  ),
                                ],
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: recentSection,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 5,
                                      child: analyticsSection,
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    recentSection,
                                    const SizedBox(height: 24),
                                    analyticsSection,
                                  ],
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSkeleton(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final items = List.generate(3, (i) {
          return Container(
            height: 96,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceSubtle
                  : AppColors.lightSurfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.darkCardBorder
                    : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  width: 80,
                  height: 16,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 50,
                  height: 12,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        });

        if (isNarrow) {
          return Column(
            children: items
                .map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: w,
                    ))
                .toList(),
          );
        }

        return Row(
          children: [
            Expanded(child: items[0]),
            const SizedBox(width: 12),
            Expanded(child: items[1]),
            const SizedBox(width: 12),
            Expanded(child: items[2]),
          ],
        );
      },
    );
  }

  Widget _buildRecentSection(
    BuildContext context, {
    required List<Animal> animals,
    required VoidCallback? onNavigateToHerd,
  }) {
    final theme = Theme.of(context);
    final recent = [...animals]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final lastAnimals = recent.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Derniers ajouts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: onNavigateToHerd,
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (animals.isEmpty)
          AgriCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              children: [
                const EmptyState(
                  icon: Icons.pets_outlined,
                  title: 'Aucun animal enregistré',
                  subtitle:
                      'Ajoutez un premier animal pour commencer à suivre votre cheptel.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddAnimalScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter un animal'),
                ),
              ],
            ),
          )
        else
          ...lastAnimals.map((animal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentAnimalCard(
                animal: animal,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnimalDetailScreen(animal: animal),
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }
}

// ─── Bandeau contextuel sous l'AppBar ───────────────────────────────────────
class _ContextBanner extends StatelessWidget {
  final String dateString;
  final int animalsCount;

  const _ContextBanner({
    required this.dateString,
    required this.animalsCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    dateString,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$animalsCount têtes',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grille des 4 cartes KPI ────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final DashboardStats stats;
  final double averageWeight;
  final double totalWeight;
  final NumberFormat currencyFmt;

  const _KpiGrid({
    required this.stats,
    required this.averageWeight,
    required this.totalWeight,
    required this.currencyFmt,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final is4Columns = constraints.maxWidth >= 480;
        final crossAxisCount = is4Columns ? 4 : 2;
        final childAspectRatio = is4Columns ? 1.3 : 1.25;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // KPI 1 : Animaux
            _KpiCard(
              title: 'Animaux',
              value: '${stats.totalAnimals}',
              subtitle: 'Total cheptel',
              icon: Icons.pets_rounded,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),

            // KPI 2 : Dépenses
            _KpiCard(
              title: 'Dépenses',
              value: _formatAmount(stats.totalMonthlyExpenses),
              subtitle: 'Ce mois (FCFA)',
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF0284C7),
            ),

            // KPI 3 : Alertes Santé
            _KpiCard(
              title: 'Alertes',
              value: '${stats.healthAlerts}',
              subtitle:
                  stats.healthAlerts > 0 ? 'Santé à suivre' : 'Tout va bien',
              icon: stats.healthAlerts > 0
                  ? Icons.warning_amber_rounded
                  : Icons.verified_rounded,
              color: stats.healthAlerts > 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
            ),

            // KPI 4 : Poids Moyen
            _KpiCard(
              title: 'Poids Moyen',
              value: stats.totalAnimals > 0
                  ? '${averageWeight.toStringAsFixed(0)} kg'
                  : '0 kg',
              subtitle: '${totalWeight.toStringAsFixed(0)} kg total',
              icon: Icons.monitor_weight_outlined,
              color: const Color(0xFFD97706),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AgriCard(
      padding: const EdgeInsets.all(14),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AgriIconContainer(
                  icon: icon,
                  color: color,
                  size: 38,
                  iconSize: 20,
                  borderRadius: 10,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Actions Rapides ────────────────────────────────────────────────────────
class _QuickActionsCard extends StatelessWidget {
  final VoidCallback? onNavigateToHerd;

  const _QuickActionsCard({this.onNavigateToHerd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AgriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions rapides',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _QuickActionTile(
            icon: Icons.add_circle_outline_rounded,
            title: 'Ajouter un animal',
            subtitle: 'Enregistrer une nouvelle tête',
            color: const Color(0xFF16A34A),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddAnimalScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.pets_rounded,
            title: 'Consulter le cheptel',
            subtitle: 'Voir la liste et filtrer les animaux',
            color: const Color(0xFF0284C7),
            onTap: onNavigateToHerd,
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Suivi sanitaire',
            subtitle: 'Consulter les statuts de santé',
            color: const Color(0xFFD97706),
            onTap: onNavigateToHerd,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSubtle
                : AppColors.lightSurfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: Row(
            children: [
              AgriIconContainer(
                icon: icon,
                color: color,
                size: 36,
                iconSize: 18,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Carte d'un animal récent (Activité récente) ────────────────────────────
class _RecentAnimalCard extends StatelessWidget {
  final Animal animal;
  final VoidCallback onTap;

  const _RecentAnimalCard({
    required this.animal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AgriCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          // Avatar vectoriel propre par espèce (sans emoji)
          SpeciesAvatar(
            type: animal.type,
            imageUrl: animal.imageUrl,
            size: 48,
            borderRadius: 12,
          ),
          const SizedBox(width: 14),

          // Informations de l'animal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        animal.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    HealthStatusBadge(
                      status: animal.healthStatus,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${animal.type.label} • ${animal.ageMonths} mois • ${animal.weightKg} kg',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

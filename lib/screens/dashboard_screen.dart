// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/animals_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/stat_card.dart';
import 'animal_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final animalsAsync = ref.watch(animalsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final currencyFmt = NumberFormat.currency(
      locale: 'fr_CI',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AgriTrack 🌿',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'Tableau de bord',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: theme.colorScheme.onPrimary,
                ),
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).toggle(),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ─── Body ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Stats Cards ─────────────────────────────────
                statsAsync.when(
                  loading: () => const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Erreur: $e'),
                  data: (stats) => LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isWide = constraints.maxWidth > 500;
                      return GridView.count(
                        crossAxisCount: isWide ? 3 : 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          StatCard(
                            title: 'Animaux',
                            value: '${stats.totalAnimals}',
                            icon: Icons.pets,
                            color: theme.colorScheme.primary,
                            subtitle: 'Total cheptel',
                          ),
                          StatCard(
                            title: 'Dépenses',
                            value: _formatAmount(
                                stats.totalMonthlyExpenses, currencyFmt),
                            icon: Icons.account_balance_wallet_outlined,
                            color: const Color(0xFF1565C0),
                            subtitle: 'Ce mois',
                          ),
                          StatCard(
                            title: 'Alertes',
                            value: '${stats.healthAlerts}',
                            icon: Icons.warning_amber_rounded,
                            color: stats.healthAlerts > 0
                                ? const Color(0xFFB71C1C)
                                : const Color(0xFF1B5E20),
                            subtitle: stats.healthAlerts > 0
                                ? 'Santé à suivre'
                                : 'Tout va bien',
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Section : Derniers ajouts ────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Derniers ajouts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Voir tout'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                animalsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Erreur: $e'),
                  data: (animals) {
                    final recent = [...animals]
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    final lastThree = recent.take(3).toList();

                    return Column(
                      children: lastThree.map((animal) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecentAnimalTile(
                            animal: animal,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AnimalDetailScreen(animal: animal),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount, NumberFormat fmt) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

class _RecentAnimalTile extends StatelessWidget {
  final dynamic animal;
  final VoidCallback onTap;

  const _RecentAnimalTile({required this.animal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Hero(
                tag: 'animal-avatar-${animal.id}',
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      animal.type.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${animal.type.label} • ${animal.ageMonths} mois • ${animal.weightKg}kg',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

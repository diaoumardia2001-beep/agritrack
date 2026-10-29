// lib/screens/animal_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/animal.dart';
import '../providers/active_farm_provider.dart';
import '../providers/animals_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agritrack_logo.dart';
import '../widgets/animal_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/search_filter_bar.dart';
import 'add_animal_screen.dart';
import 'animal_detail_screen.dart';

class AnimalListScreen extends ConsumerStatefulWidget {
  const AnimalListScreen({super.key});

  @override
  ConsumerState<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends ConsumerState<AnimalListScreen> {
  bool _isListView = false;

  void _navigateToDetail(BuildContext context, Animal animal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalDetailScreen(animal: animal),
      ),
    );
  }

  void _navigateToAddAnimal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddAnimalScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredAnimalsProvider);
    final allAnimalsAsync = ref.watch(animalsProvider);
    final allAnimals = allAnimalsAsync.valueOrNull ?? const [];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalCount = allAnimals.length;
    final distinctSpecies = allAnimals.map((a) => a.type).toSet().length;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AgriTrackLogo(size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mon Cheptel',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    totalCount > 0
                        ? '$totalCount ${totalCount > 1 ? 'animaux' : 'animal'} • $distinctSpecies ${distinctSpecies > 1 ? 'espèces' : 'espèce'}'
                        : 'Gestion du troupeau',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          // ── Bascule Grille / Liste ──
          IconButton(
            tooltip:
                _isListView ? 'Passer en vue grille' : 'Passer en vue liste',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _isListView ? Icons.grid_view_rounded : Icons.view_list_rounded,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            onPressed: () => setState(() => _isListView = !_isListView),
          ),

          // ── Bouton d'ajout d'un animal ──
          IconButton(
            tooltip: 'Ajouter un animal',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            onPressed: () => _navigateToAddAnimal(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // ─── Barre de recherche, filtres et tri ────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SearchFilterBar(),
              ),

              // ─── Contenu principal du cheptel ──────────────────────────
              Expanded(
                child: filteredAsync.when(
                  loading: () => _buildListSkeleton(isDark),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erreur lors du chargement du cheptel\n$e',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => ref.refresh(animalsProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (animals) {
                    final activeFarm = ref.watch(activeFarmProvider).activeFarm;
                    final isRemoteFarm = activeFarm.isRemote;

                    // Cas 1 : La ferme active ne contient aucun animal localement
                    if (allAnimals.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              EmptyState(
                                icon: isRemoteFarm
                                    ? Icons.cloud_off_rounded
                                    : Icons.pets_outlined,
                                title: isRemoteFarm
                                    ? 'Aucun animal local pour "${activeFarm.name}"'
                                    : 'Votre cheptel est vide',
                                subtitle: isRemoteFarm
                                    ? 'Cette exploitation distante ne dispose pas encore de données enregistrées localement sur cet appareil. Les données cloud ne sont pas encore synchronisées.'
                                    : 'Commencez par ajouter votre premier animal pour débuter le suivi de votre exploitation.',
                              ),
                              const SizedBox(height: 20),
                              if (ref.watch(activeFarmProvider).canAddAnimal)
                                FilledButton.icon(
                                  onPressed: () =>
                                      _navigateToAddAnimal(context),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Ajouter un animal'),
                                ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Cas 2 : Des animaux existent, mais aucun ne correspond au filtre ou à la recherche
                    if (animals.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'Aucun animal trouvé',
                                subtitle:
                                    'Aucun animal ne correspond à vos critères actuels de recherche ou de filtre.',
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ref
                                      .read(animalFilterProvider.notifier)
                                      .reset();
                                },
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Effacer les filtres'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Cas 3 : Liste des animaux filtrés
                    return LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isNarrow = constraints.maxWidth < 640;

                        // ── Mode Liste compacte ──
                        if (_isListView) {
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: animals.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final animal = animals[i];
                              return AnimalCard(
                                animal: animal,
                                isListView: true,
                                onTap: () => _navigateToDetail(context, animal),
                              );
                            },
                          );
                        }

                        // ── Mode Grille sur mobile (<640px) ──
                        // Sur mobile, 1 colonne aérée pour une lisibilité optimale et sans overflow
                        if (isNarrow) {
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: animals.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final animal = animals[i];
                              return AnimalCard(
                                animal: animal,
                                isListView: false,
                                onTap: () => _navigateToDetail(context, animal),
                              );
                            },
                          );
                        }

                        // ── Mode Grille sur tablette et desktop (>=640px) ──
                        final crossAxisCount =
                            constraints.maxWidth >= 1050 ? 3 : 2;
                        final childAspectRatio =
                            constraints.maxWidth >= 1050 ? 1.48 : 1.45;

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: animals.length,
                          itemBuilder: (ctx, i) {
                            final animal = animals[i];
                            return AnimalCard(
                              animal: animal,
                              isListView: false,
                              onTap: () => _navigateToDetail(context, animal),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListSkeleton(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        return Container(
          height: 180,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSubtle
                : AppColors.lightSurfaceSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 120,
                      height: 18,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 18,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

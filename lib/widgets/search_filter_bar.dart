// lib/widgets/search_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/animal.dart';
import '../providers/animals_provider.dart';
import '../theme/app_colors.dart';

class SearchFilterBar extends ConsumerStatefulWidget {
  const SearchFilterBar({super.key});

  @override
  ConsumerState<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<SearchFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(animalFilterProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(animalFilterProvider);
    final counts = ref.watch(speciesCountsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Synchronisation si le filtre a été réinitialisé de l'extérieur
    if (_controller.text != filter.searchQuery && filter.searchQuery.isEmpty) {
      _controller.text = '';
    }

    final hasActiveFilter = filter.searchQuery.trim().isNotEmpty ||
        filter.selectedType != null ||
        filter.sortCriteria != AnimalSortCriteria.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Rangée : Recherche & Menu de Tri ────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (val) =>
                    ref.read(animalFilterProvider.notifier).setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Rechercher un animal...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            ref
                                .read(animalFilterProvider.notifier)
                                .setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurfaceSubtle
                      : AppColors.lightSurfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Menu de tri ──
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceSubtle
                    : AppColors.lightSurfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: filter.sortCriteria != AnimalSortCriteria.none
                      ? (isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary)
                      : (isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder),
                ),
              ),
              child: PopupMenuButton<AnimalSortCriteria>(
                tooltip: 'Trier par...',
                icon: Icon(
                  Icons.sort_rounded,
                  color: filter.sortCriteria != AnimalSortCriteria.none
                      ? (isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                initialValue: filter.sortCriteria,
                onSelected: (criteria) {
                  ref.read(animalFilterProvider.notifier).setSort(criteria);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: AnimalSortCriteria.none,
                    child: Text('Ordre initial'),
                  ),
                  const PopupMenuItem(
                    value: AnimalSortCriteria.name,
                    child: Text('Nom'),
                  ),
                  const PopupMenuItem(
                    value: AnimalSortCriteria.weight,
                    child: Text('Poids'),
                  ),
                  const PopupMenuItem(
                    value: AnimalSortCriteria.createdAt,
                    child: Text('Date d\'ajout'),
                  ),
                  const PopupMenuItem(
                    value: AnimalSortCriteria.expenses,
                    child: Text('Dépenses cumulées'),
                  ),
                ],
              ),
            ),

            // ── Bascule croissant / décroissant si tri actif ──
            if (filter.sortCriteria != AnimalSortCriteria.none) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: filter.sortAscending
                    ? 'Croissant (cliquer pour inverser)'
                    : 'Décroissant (cliquer pour inverser)',
                icon: Icon(
                  filter.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 20,
                  color:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
                onPressed: () {
                  ref.read(animalFilterProvider.notifier).toggleSortDirection();
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ─── Rangée : Chips de filtres avec compteurs réels ──────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Tous',
                count: counts[null],
                selected: filter.selectedType == null,
                onTap: () =>
                    ref.read(animalFilterProvider.notifier).setType(null),
              ),
              const SizedBox(width: 8),
              ...AnimalType.values.map((type) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: '${type.emoji} ${type.label}',
                      count: counts[type],
                      speciesColor: AppColors.forSpecies(type),
                      selected: filter.selectedType == type,
                      onTap: () =>
                          ref.read(animalFilterProvider.notifier).setType(type),
                    ),
                  )),
            ],
          ),
        ),

        // ─── Bandeau informatif si filtres ou tri actifs ─────────────
        if (hasActiveFilter) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (filter.sortCriteria != AnimalSortCriteria.none)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter.sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tri: ${filter.sortCriteria.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _controller.clear();
                  ref.read(animalFilterProvider.notifier).reset();
                },
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text(
                  'Réinitialiser',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final Color? speciesColor;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.count,
    this.speciesColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: count != null ? '$label, $count éléments' : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.14)
                  : (isDark
                      ? AppColors.darkSurfaceSubtle
                      : AppColors.lightSurfaceSubtle),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? primaryColor
                    : (isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder),
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color:
                        selected ? primaryColor : theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isDark ? Colors.white24 : Colors.black12)
                          : (isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? (isDark ? Colors.white : primaryColor)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

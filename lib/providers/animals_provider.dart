// lib/providers/animals_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/animals_repository.dart';
import '../models/animal.dart';

// ─── Repository singleton ───────────────────────────────────────────────────
final animalsRepositoryProvider = Provider<AnimalsRepository>((ref) {
  return AnimalsRepository();
});

// ─── FutureProvider : chargement async de la liste complète ─────────────────
final animalsProvider = FutureProvider<List<Animal>>((ref) async {
  final repo = ref.watch(animalsRepositoryProvider);
  return repo.fetchAnimals();
});

// ─── Filtre : état de la recherche/filtrage ──────────────────────────────────
class AnimalFilter {
  final String searchQuery;
  final AnimalType? selectedType;

  const AnimalFilter({
    this.searchQuery = '',
    this.selectedType,
  });

  AnimalFilter copyWith({
    String? searchQuery,
    AnimalType? selectedType,
    bool clearType = false,
  }) {
    return AnimalFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
    );
  }
}

class AnimalFilterNotifier extends StateNotifier<AnimalFilter> {
  AnimalFilterNotifier() : super(const AnimalFilter());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setType(AnimalType? type) {
    if (state.selectedType == type) {
      state = state.copyWith(clearType: true);
    } else {
      state = state.copyWith(selectedType: type);
    }
  }

  void reset() {
    state = const AnimalFilter();
  }
}

final animalFilterProvider =
    StateNotifierProvider<AnimalFilterNotifier, AnimalFilter>((ref) {
  return AnimalFilterNotifier();
});

// ─── Provider dérivé : liste filtrée ────────────────────────────────────────
final filteredAnimalsProvider = Provider<AsyncValue<List<Animal>>>((ref) {
  final asyncAnimals = ref.watch(animalsProvider);
  final filter = ref.watch(animalFilterProvider);

  return asyncAnimals.when(
    data: (animals) {
      var filtered = animals;

      if (filter.selectedType != null) {
        filtered =
            filtered.where((a) => a.type == filter.selectedType).toList();
      }

      if (filter.searchQuery.isNotEmpty) {
        final q = filter.searchQuery.toLowerCase();
        filtered = filtered
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.type.label.toLowerCase().contains(q))
            .toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ─── Dashboard stats ─────────────────────────────────────────────────────────
class DashboardStats {
  final int totalAnimals;
  final double totalMonthlyExpenses;
  final int healthAlerts;

  const DashboardStats({
    required this.totalAnimals,
    required this.totalMonthlyExpenses,
    required this.healthAlerts,
  });
}

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final asyncAnimals = ref.watch(animalsProvider);

  return asyncAnimals.when(
    data: (animals) {
      final totalAnimals = animals.length;
      final totalMonthly =
          animals.fold<double>(0, (sum, a) => sum + a.monthlyExpenses);
      final alerts = animals
          .where((a) =>
              a.healthStatus == HealthStatus.aSurveiller ||
              a.healthStatus == HealthStatus.malade)
          .length;

      return AsyncValue.data(DashboardStats(
        totalAnimals: totalAnimals,
        totalMonthlyExpenses: totalMonthly,
        healthAlerts: alerts,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

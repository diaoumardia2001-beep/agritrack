import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/animals_repository.dart';
import '../data/database/database_migrator.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/sync_queue_operation.dart';
import 'active_farm_provider.dart';
import 'auth_provider.dart';
import 'sync_provider.dart';

// ─── Repository singleton ───────────────────────────────────────────────────
final animalsRepositoryProvider = Provider<AnimalsRepository>((ref) {
  return AnimalsRepository();
});

// ─── FutureProvider : chargement async de la liste des fermes ───────────────
final farmsProvider = FutureProvider<List<Farm>>((ref) async {
  final repo = ref.watch(animalsRepositoryProvider);
  return repo.fetchFarms();
});

// ─── FutureProvider : chargement async des animaux de la ferme active ───────
final animalsProvider = FutureProvider<List<Animal>>((ref) async {
  final repo = ref.watch(animalsRepositoryProvider);
  final activeFarmId = ref.watch(activeFarmIdProvider);
  return repo.fetchAnimals(farmId: activeFarmId);
});

// ─── Critères de tri pour le cheptel ─────────────────────────────────────────
enum AnimalSortCriteria {
  none('Ordre initial'),
  name('Nom'),
  weight('Poids'),
  createdAt('Date d\'ajout'),
  expenses('Dépenses cumulées');

  final String label;
  const AnimalSortCriteria(this.label);
}

// ─── Filtre : état de la recherche/filtrage/tri ──────────────────────────────
class AnimalFilter {
  final String searchQuery;
  final AnimalType? selectedType;
  final AnimalSortCriteria sortCriteria;
  final bool sortAscending;

  const AnimalFilter({
    this.searchQuery = '',
    this.selectedType,
    this.sortCriteria = AnimalSortCriteria.none,
    this.sortAscending = true,
  });

  AnimalFilter copyWith({
    String? searchQuery,
    AnimalType? selectedType,
    bool clearType = false,
    AnimalSortCriteria? sortCriteria,
    bool? sortAscending,
  }) {
    return AnimalFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
      sortCriteria: sortCriteria ?? this.sortCriteria,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

class AnimalFilterNotifier extends StateNotifier<AnimalFilter> {
  AnimalFilterNotifier() : super(const AnimalFilter());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setType(AnimalType? type) {
    if (state.selectedType == type || type == null) {
      state = state.copyWith(clearType: true);
    } else {
      state = state.copyWith(selectedType: type);
    }
  }

  void setSort(AnimalSortCriteria criteria, {bool? ascending}) {
    if (ascending == null && state.sortCriteria == criteria) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      final defaultAscending = criteria == AnimalSortCriteria.name;
      state = state.copyWith(
        sortCriteria: criteria,
        sortAscending: ascending ?? defaultAscending,
      );
    }
  }

  void toggleSortDirection() {
    state = state.copyWith(sortAscending: !state.sortAscending);
  }

  void reset() {
    state = const AnimalFilter();
  }
}

final animalFilterProvider =
    StateNotifierProvider<AnimalFilterNotifier, AnimalFilter>((ref) {
  return AnimalFilterNotifier();
});

// ─── Provider dérivé : liste filtrée et triée ───────────────────────────────
final filteredAnimalsProvider = Provider<AsyncValue<List<Animal>>>((ref) {
  final asyncAnimals = ref.watch(animalsProvider);
  final filter = ref.watch(animalFilterProvider);

  return asyncAnimals.when(
    data: (animals) {
      var filtered = [...animals];

      if (filter.selectedType != null) {
        filtered =
            filtered.where((a) => a.type == filter.selectedType).toList();
      }

      final q = filter.searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        filtered = filtered
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.type.label.toLowerCase().contains(q))
            .toList();
      }

      // ─── Tri en mémoire (sans altérer la base ni les données persistées) ──
      if (filter.sortCriteria != AnimalSortCriteria.none) {
        filtered.sort((a, b) {
          int cmp;
          switch (filter.sortCriteria) {
            case AnimalSortCriteria.name:
              cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
              break;
            case AnimalSortCriteria.weight:
              cmp = a.weightKg.compareTo(b.weightKg);
              break;
            case AnimalSortCriteria.createdAt:
              cmp = a.createdAt.compareTo(b.createdAt);
              break;
            case AnimalSortCriteria.expenses:
              cmp = a.totalExpenses.compareTo(b.totalExpenses);
              break;
            case AnimalSortCriteria.none:
              cmp = 0;
              break;
          }
          if (cmp == 0) {
            // Bris d'égalité déterministe et stable par ID
            cmp = a.id.compareTo(b.id);
          }
          return filter.sortAscending ? cmp : -cmp;
        });
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ─── Provider dérivé : compteurs réels par espèce ────────────────────────────
final speciesCountsProvider = Provider<Map<AnimalType?, int>>((ref) {
  final asyncAnimals = ref.watch(animalsProvider);
  final animals = asyncAnimals.valueOrNull ?? [];
  final counts = <AnimalType?, int>{
    null: animals.length,
  };
  for (final type in AnimalType.values) {
    counts[type] = animals.where((a) => a.type == type).length;
  }
  return counts;
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

// ─── Provider dérivé pour un animal spécifique par son ID ───────────────────
final animalByIdProvider = Provider.family<Animal?, String>((ref, id) {
  final asyncAnimals = ref.watch(animalsProvider);
  final list = asyncAnimals.valueOrNull;
  if (list == null) return null;
  for (final a in list) {
    if (a.id == id) return a;
  }
  return null;
});

// ─── Notifier pour les mutations (animaux, dépenses) ─────────────────────────
class AnimalsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AnimalsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Enfile de façon asynchrone et résiliente une opération dans la file de synchronisation.
  /// Garantit qu'une anomalie dans la file n'annule jamais la mutation locale dans Sembast.
  Future<void> _safeEnqueue({
    required SyncEntityType entityType,
    required String localId,
    required SyncAction action,
    required String farmId,
    bool isDemo = false,
    Map<String, dynamic>? payload,
  }) async {
    final cleanFarmId = farmId.trim();
    final cleanLocalId = localId.trim();

    // 1. Exclure immédiatement toute exploitation locale ou par défaut
    if (cleanFarmId.isEmpty ||
        cleanFarmId == DatabaseMigrator.defaultFarmId ||
        cleanFarmId.startsWith('local_')) {
      return;
    }

    // 2. Exclure formellement toute donnée marquée démo ou identifiant de démo officiel
    if (isDemo) {
      return;
    }
    if (entityType == SyncEntityType.animal &&
        DatabaseMigrator.knownDemoAnimalIds.contains(cleanLocalId)) {
      return;
    }
    if (entityType == SyncEntityType.expense &&
        DatabaseMigrator.knownDemoExpenseIds.contains(cleanLocalId)) {
      return;
    }

    try {
      final queueService = _ref.read(syncQueueServiceProvider);
      final authState = _ref.read(authProvider);

      await queueService.enqueue(
        entityType: entityType,
        localId: cleanLocalId,
        action: action,
        farmId: cleanFarmId,
        userId: authState.userId,
        isDemo: isDemo,
        payload: payload,
      );
    } catch (e, st) {
      debugPrint(
        '[AnimalsNotifier] Erreur résiliente lors de l\'enfilement sync ($entityType, $cleanLocalId, $action): $e\n$st',
      );
    }
  }

  /// Ajoute une dépense à un animal et actualise le cache Riverpod.
  /// Vérifie les permissions du rôle actif et l'appartenance à la ferme active.
  /// Enfile l'opération dans la file de synchronisation si la ferme est distante.
  Future<Expense> addExpense({
    required String animalId,
    required Expense expense,
  }) async {
    state = const AsyncValue.loading();
    try {
      final activeFarmState = _ref.read(activeFarmProvider);
      if (!activeFarmState.canAddExpense) {
        throw StateError(
          'Action non autorisée : vous n\'avez pas les permissions pour ajouter une dépense sur cette exploitation.',
        );
      }

      final repo = _ref.read(animalsRepositoryProvider);
      final animal = await repo.getAnimalById(animalId);
      if (animal == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "$animalId".');
      }

      if (animal.farmId != activeFarmState.activeFarm.id) {
        throw StateError(
          'Action non autorisée : cet animal n\'appartient pas à l\'exploitation active.',
        );
      }

      final isRemote = activeFarmState.isRemote;
      final expenseToSave = expense.copyWith(
        farmId: activeFarmState.activeFarm.id,
        animalId: animalId,
        syncStatus: isRemote ? SyncStatus.pendingCreate : expense.syncStatus,
      );

      // 1. Sauvegarde locale prioritaire dans Sembast
      final created = await repo.addExpense(animalId, expenseToSave);

      // 2. Enfilement résilient dans sync_queue
      await _safeEnqueue(
        entityType: SyncEntityType.expense,
        localId: created.id,
        action: SyncAction.create,
        farmId: activeFarmState.activeFarm.id,
        isDemo: animal.isDemo,
        payload: {
          'animalId': animalId,
        },
      );

      _ref.invalidate(animalsProvider);
      await _ref.read(animalsProvider.future);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Met à jour une dépense existante d'un animal.
  /// Protégé : les ouvriers (workers) ne peuvent pas modifier de dépenses (RLS SQL).
  /// Enfile l'opération dans la file de synchronisation si la ferme est distante.
  Future<Expense> updateExpense({
    required String animalId,
    required Expense expense,
  }) async {
    state = const AsyncValue.loading();
    try {
      final activeFarmState = _ref.read(activeFarmProvider);
      if (!activeFarmState.canUpdateExpense) {
        throw StateError(
          'Action non autorisée : les ouvriers ne peuvent pas modifier les dépenses financières.',
        );
      }

      final repo = _ref.read(animalsRepositoryProvider);
      final animal = await repo.getAnimalById(animalId);
      if (animal == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "$animalId".');
      }

      if (animal.farmId != activeFarmState.activeFarm.id) {
        throw StateError(
          'Action non autorisée : cet animal n\'appartient pas à l\'exploitation active.',
        );
      }

      final existingExpense = animal.expenses.firstWhere(
        (e) => e.id == expense.id,
        orElse: () => expense,
      );

      final isRemote = activeFarmState.isRemote;
      final targetSyncStatus = isRemote
          ? (existingExpense.syncStatus == SyncStatus.pendingCreate
              ? SyncStatus.pendingCreate
              : SyncStatus.pendingUpdate)
          : expense.syncStatus;

      final expenseToUpdate = expense.copyWith(
        farmId: activeFarmState.activeFarm.id,
        animalId: animalId,
        syncStatus: targetSyncStatus,
      );

      // 1. Sauvegarde locale prioritaire dans Sembast
      final updated = await repo.updateExpense(animalId, expenseToUpdate);

      // 2. Enfilement résilient dans sync_queue
      await _safeEnqueue(
        entityType: SyncEntityType.expense,
        localId: updated.id,
        action: SyncAction.update,
        farmId: activeFarmState.activeFarm.id,
        isDemo: animal.isDemo,
        payload: {
          'animalId': animalId,
        },
      );

      _ref.invalidate(animalsProvider);
      await _ref.read(animalsProvider.future);
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Supprime une dépense financière d'un animal.
  /// Protégé : seuls les gestionnaires et propriétaires peuvent supprimer une dépense (RLS SQL).
  /// Enfile l'opération dans la file de synchronisation si la ferme est distante.
  Future<bool> deleteExpense({
    required String animalId,
    required String expenseId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final activeFarmState = _ref.read(activeFarmProvider);
      if (!activeFarmState.canDeleteExpense) {
        throw StateError(
          'Action non autorisée : les ouvriers ne peuvent pas supprimer les dépenses financières.',
        );
      }

      final repo = _ref.read(animalsRepositoryProvider);
      final animal = await repo.getAnimalById(animalId);
      if (animal == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "$animalId".');
      }

      if (animal.farmId != activeFarmState.activeFarm.id) {
        throw StateError(
          'Action non autorisée : cet animal n\'appartient pas à l\'exploitation active.',
        );
      }

      final existingExpenseIndex =
          animal.expenses.indexWhere((e) => e.id == expenseId);
      final existingExpense = existingExpenseIndex != -1
          ? animal.expenses[existingExpenseIndex]
          : null;

      // 1. Suppression locale dans Sembast
      final deleted = await repo.deleteExpense(animalId, expenseId);

      // 2. Enfilement résilient dans sync_queue
      if (deleted) {
        await _safeEnqueue(
          entityType: SyncEntityType.expense,
          localId: expenseId,
          action: SyncAction.delete,
          farmId: activeFarmState.activeFarm.id,
          isDemo: animal.isDemo,
          payload: {
            'animalId': animalId,
            if (existingExpense?.remoteId != null)
              'remoteId': existingExpense!.remoteId,
          },
        );
      }

      _ref.invalidate(animalsProvider);
      await _ref.read(animalsProvider.future);
      state = const AsyncValue.data(null);
      return deleted;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Ajoute un animal à la base et actualise le cache Riverpod.
  /// Associe systématiquement l'animal à l'exploitation active.
  /// Enfile l'opération dans la file de synchronisation si la ferme est distante.
  Future<Animal> addAnimal(Animal animal) async {
    state = const AsyncValue.loading();
    try {
      final activeFarmState = _ref.read(activeFarmProvider);
      if (!activeFarmState.canAddAnimal) {
        throw StateError(
          'Action non autorisée : vous n\'avez pas les permissions pour ajouter un animal.',
        );
      }

      final repo = _ref.read(animalsRepositoryProvider);
      // Rapprochement avec la ferme active si l'animal avait un farmId non spécifié ou par défaut
      final targetFarmId =
          (animal.farmId.isNotEmpty && animal.farmId != 'local_default_farm')
              ? animal.farmId
              : activeFarmState.activeFarm.id;

      final isRemote = targetFarmId != DatabaseMigrator.defaultFarmId &&
          !targetFarmId.startsWith('local_');

      final animalToInsert = animal.copyWith(
        farmId: targetFarmId,
        syncStatus: isRemote ? SyncStatus.pendingCreate : animal.syncStatus,
      );

      // 1. Sauvegarde locale prioritaire dans Sembast
      final created =
          await repo.addAnimal(animalToInsert, targetFarmId: targetFarmId);

      // 2. Enfilement résilient dans sync_queue
      await _safeEnqueue(
        entityType: SyncEntityType.animal,
        localId: created.id,
        action: SyncAction.create,
        farmId: targetFarmId,
        isDemo: created.isDemo,
      );

      _ref.invalidate(animalsProvider);
      await _ref.read(animalsProvider.future);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Met à jour un animal existant dans la base et actualise le cache Riverpod.
  /// Vérifie les permissions et interdit de changer de ferme.
  /// Enfile l'opération dans la file de synchronisation si la ferme est distante.
  Future<Animal> updateAnimal(Animal animal) async {
    state = const AsyncValue.loading();
    try {
      final activeFarmState = _ref.read(activeFarmProvider);
      if (!activeFarmState.canUpdateAnimal) {
        throw StateError(
          'Action non autorisée : vous n\'avez pas les permissions pour modifier cet animal.',
        );
      }

      final repo = _ref.read(animalsRepositoryProvider);
      final existing = await repo.getAnimalById(animal.id);
      if (existing != null &&
          existing.farmId != activeFarmState.activeFarm.id) {
        throw StateError(
          'Action non autorisée : cet animal n\'appartient pas à l\'exploitation active.',
        );
      }

      final isRemote = activeFarmState.isRemote;
      final targetSyncStatus = isRemote
          ? (existing?.syncStatus == SyncStatus.pendingCreate
              ? SyncStatus.pendingCreate
              : SyncStatus.pendingUpdate)
          : animal.syncStatus;

      // Préserver la ferme de rattachement
      final animalToUpdate = animal.copyWith(
        farmId: activeFarmState.activeFarm.id,
        syncStatus: targetSyncStatus,
      );

      // 1. Sauvegarde locale prioritaire dans Sembast
      final updated = await repo.updateAnimal(animalToUpdate);

      // 2. Enfilement résilient dans sync_queue
      await _safeEnqueue(
        entityType: SyncEntityType.animal,
        localId: updated.id,
        action: SyncAction.update,
        farmId: activeFarmState.activeFarm.id,
        isDemo: updated.isDemo,
      );

      _ref.invalidate(animalsProvider);
      await _ref.read(animalsProvider.future);
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Supprime logiquement un animal et actualise le cache Riverpod.
  /// Protégé : seuls les gestionnaires et propriétaires peuvent supprimer un animal (RLS SQL).
  /// Enfile l'opération dans la file de synchronisation si la ferme est distante.
  Future<bool> deleteAnimal(String animalId) async {
    state = const AsyncValue.loading();
    try {
      final activeFarmState = _ref.read(activeFarmProvider);
      if (!activeFarmState.canDeleteAnimal) {
        throw StateError(
          'Action non autorisée : les ouvriers ne peuvent pas supprimer d\'animaux.',
        );
      }

      final repo = _ref.read(animalsRepositoryProvider);
      final animal = await repo.getAnimalById(animalId);
      if (animal == null) {
        return false;
      }

      if (animal.farmId != activeFarmState.activeFarm.id) {
        throw StateError(
          'Action non autorisée : cet animal n\'appartient pas à l\'exploitation active.',
        );
      }

      // 1. Suppression logique locale dans Sembast
      final deleted = await repo.deleteAnimal(animalId);

      // 2. Enfilement résilient dans sync_queue
      if (deleted) {
        await _safeEnqueue(
          entityType: SyncEntityType.animal,
          localId: animal.id,
          action: SyncAction.delete,
          farmId: activeFarmState.activeFarm.id,
          isDemo: animal.isDemo,
        );
      }

      _ref.invalidate(animalsProvider);
      await _ref.read(animalsProvider.future);
      state = const AsyncValue.data(null);
      return deleted;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final animalsNotifierProvider =
    StateNotifierProvider<AnimalsNotifier, AsyncValue<void>>((ref) {
  return AnimalsNotifier(ref);
});

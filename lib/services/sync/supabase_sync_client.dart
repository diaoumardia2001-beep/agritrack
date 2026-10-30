// lib/services/sync/supabase_sync_client.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

/// Statut du résultat retourné par les RPC de synchronisation optimiste.
enum PushResultStatus {
  success,
  conflict,
}

/// Résultat structuré retourné par les procédures stockées [sync_push_animal] et [sync_push_expense].
class SyncPushResult {
  final PushResultStatus status;
  final String? remoteId;
  final int? versionId;
  final DateTime? updatedAt;
  final int? serverVersion;
  final int? expectedVersion;
  final Map<String, dynamic>? serverData;
  final String? rawAction;

  const SyncPushResult.success({
    required this.remoteId,
    required this.versionId,
    this.updatedAt,
    this.rawAction,
  })  : status = PushResultStatus.success,
        serverVersion = null,
        expectedVersion = null,
        serverData = null;

  const SyncPushResult.conflict({
    required this.remoteId,
    required this.serverVersion,
    required this.expectedVersion,
    required this.serverData,
    this.rawAction,
  })  : status = PushResultStatus.conflict,
        versionId = null,
        updatedAt = null;

  bool get isSuccess => status == PushResultStatus.success;
  bool get isConflict => status == PushResultStatus.conflict;

  factory SyncPushResult.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'error';
    if (statusStr == 'conflict') {
      return SyncPushResult.conflict(
        remoteId: json['remote_id'] as String?,
        serverVersion: (json['server_version'] as num?)?.toInt(),
        expectedVersion: (json['expected_version'] as num?)?.toInt(),
        serverData: json['server_data'] != null
            ? Map<String, dynamic>.from(json['server_data'] as Map)
            : null,
        rawAction: json['action'] as String?,
      );
    } else if (statusStr == 'success') {
      return SyncPushResult.success(
        remoteId: (json['remote_id'] ?? json['id']) as String?,
        versionId: (json['version_id'] as num?)?.toInt(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        rawAction: json['action'] as String?,
      );
    } else {
      throw FormatException(
        'Statut de retour RPC inattendu : "$statusStr" (réponse: $json)',
      );
    }
  }
}

/// Interface d'abstraction pour les échanges réseau avec Supabase.
///
/// Isole le moteur de synchronisation [SyncEngine] des dépendances directes
/// au SDK Supabase et permet une couverture de test unitaire exhaustive
/// sans dépendance réseau.
abstract class ISupabaseSyncClient {
  /// Exécute la procédure optimiste transactionnelle `sync_push_animal`.
  Future<SyncPushResult> pushAnimalRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? name,
    String? type,
    int? ageMonths,
    double? weightKg,
    String? healthStatus,
    String? imageUrl,
    DateTime? deletedAt,
  });

  /// Exécute la procédure optimiste transactionnelle `sync_push_expense`.
  Future<SyncPushResult> pushExpenseRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? animalId,
    String? label,
    double? amount,
    DateTime? date,
    String? category,
    DateTime? deletedAt,
  });

  /// Insère ou met à jour un animal de manière idempotente sur Supabase (Legacy).
  Future<String> upsertAnimal(Map<String, dynamic> animalPayload);

  /// Supprime logiquement un animal sur Supabase (`deleted_at = now()`).
  Future<void> softDeleteAnimal({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  });

  /// Insère ou met à jour une dépense de manière idempotente sur Supabase (Legacy).
  Future<String> upsertExpense(Map<String, dynamic> expensePayload);

  /// Supprime logiquement une dépense sur Supabase (`deleted_at = now()`).
  Future<void> softDeleteExpense({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  });

  /// Récupère le rôle effectif de l'utilisateur connecté sur l'exploitation distante.
  Future<String?> getMemberRole({
    required String farmId,
    required String userId,
  });

  /// Récupère de manière paginée les animaux d'une exploitation modifiés depuis [since].
  Future<List<Map<String, dynamic>>> fetchAnimals({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  });

  /// Récupère de manière paginée les dépenses d'une exploitation modifiées depuis [since].
  Future<List<Map<String, dynamic>>> fetchExpenses({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  });
}

/// Implémentation réelle utilisant le client Supabase officiel.
///
/// Utilise exclusivement la clé anonyme publique régie par RLS.
/// Aucune clé privilégiée (service_role) n'est acceptée ni exposée.
class RealSupabaseSyncClient implements ISupabaseSyncClient {
  final SupabaseClient? _client;

  RealSupabaseSyncClient({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.safeClient;

  SupabaseClient get _activeClient {
    final client = _client ?? SupabaseConfig.safeClient;
    if (client == null) {
      throw StateError(
        'Client Supabase non initialisé. Vérifiez la configuration avant toute opération réseau.',
      );
    }
    return client;
  }

  @override
  Future<SyncPushResult> pushAnimalRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? name,
    String? type,
    int? ageMonths,
    double? weightKg,
    String? healthStatus,
    String? imageUrl,
    DateTime? deletedAt,
  }) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] RPC sync_push_animal op=$operationId farm=$farmId action=$action expectedVersion=$expectedVersion',
    );

    final params = {
      'p_operation_id': operationId,
      'p_farm_id': farmId,
      'p_action': action,
      if (expectedVersion != null) 'p_expected_version': expectedVersion,
      if (localId != null) 'p_local_id': localId,
      if (remoteId != null) 'p_remote_id': remoteId,
      if (name != null) 'p_name': name,
      if (type != null) 'p_type': type,
      if (ageMonths != null) 'p_age_months': ageMonths,
      if (weightKg != null) 'p_weight_kg': weightKg,
      if (healthStatus != null) 'p_health_status': healthStatus,
      if (imageUrl != null) 'p_image_url': imageUrl,
      if (deletedAt != null) 'p_deleted_at': deletedAt.toIso8601String(),
    };

    final res = await client.rpc('sync_push_animal', params: params);
    return SyncPushResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<SyncPushResult> pushExpenseRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? animalId,
    String? label,
    double? amount,
    DateTime? date,
    String? category,
    DateTime? deletedAt,
  }) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] RPC sync_push_expense op=$operationId farm=$farmId action=$action expectedVersion=$expectedVersion',
    );

    final params = {
      'p_operation_id': operationId,
      'p_farm_id': farmId,
      'p_action': action,
      if (expectedVersion != null) 'p_expected_version': expectedVersion,
      if (localId != null) 'p_local_id': localId,
      if (remoteId != null) 'p_remote_id': remoteId,
      if (animalId != null) 'p_animal_id': animalId,
      if (label != null) 'p_label': label,
      if (amount != null) 'p_amount': amount,
      if (date != null) 'p_date': date.toIso8601String(),
      if (category != null) 'p_category': category,
      if (deletedAt != null) 'p_deleted_at': deletedAt.toIso8601String(),
    };

    final res = await client.rpc('sync_push_expense', params: params);
    return SyncPushResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<String> upsertAnimal(Map<String, dynamic> animalPayload) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] Upsert animal local_id=${animalPayload['local_id']} vers farm=${animalPayload['farm_id']}',
    );

    // Utilisation de la contrainte unique partagée (farm_id, local_id) pour l'idempotence
    final response = await client
        .from('animals')
        .upsert(
          animalPayload,
          onConflict: 'farm_id, local_id',
        )
        .select('id')
        .single();

    final remoteId = response['id'] as String?;
    if (remoteId == null || remoteId.isEmpty) {
      throw const FormatException(
        'Supabase n\'a pas retourné d\'identifiant UUID valide pour l\'animal.',
      );
    }
    return remoteId;
  }

  @override
  Future<void> softDeleteAnimal({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] Soft delete animal remoteId=$remoteId sur farm=$farmId',
    );

    await client
        .from('animals')
        .update({
          'deleted_at': deletedAt.toIso8601String(),
        })
        .eq('id', remoteId)
        .eq('farm_id', farmId);
  }

  @override
  Future<String> upsertExpense(Map<String, dynamic> expensePayload) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] Upsert dépense local_id=${expensePayload['local_id']} vers farm=${expensePayload['farm_id']}',
    );

    final response = await client
        .from('expenses')
        .upsert(
          expensePayload,
          onConflict: 'farm_id, local_id',
        )
        .select('id')
        .single();

    final remoteId = response['id'] as String?;
    if (remoteId == null || remoteId.isEmpty) {
      throw const FormatException(
        'Supabase n\'a pas retourné d\'identifiant UUID valide pour la dépense.',
      );
    }
    return remoteId;
  }

  @override
  Future<void> softDeleteExpense({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] Soft delete dépense remoteId=$remoteId sur farm=$farmId',
    );

    await client
        .from('expenses')
        .update({
          'deleted_at': deletedAt.toIso8601String(),
        })
        .eq('id', remoteId)
        .eq('farm_id', farmId);
  }

  @override
  Future<String?> getMemberRole({
    required String farmId,
    required String userId,
  }) async {
    final client = _activeClient;
    try {
      final res = await client
          .from('farm_members')
          .select('role')
          .eq('farm_id', farmId)
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) return null;
      return res['role'] as String?;
    } catch (e) {
      debugPrint('[SupabaseSync] Erreur lors de la vérification du rôle: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAnimals({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] Fetch animals farm=$farmId, since=$since, lastId=$lastId, limit=$limit',
    );

    var query = client
        .from('animals')
        .select()
        .eq('farm_id', farmId);

    if (since != null) {
      final sinceIso = since.toIso8601String();
      if (lastId != null && lastId.isNotEmpty) {
        query = query.or(
          'updated_at.gt.$sinceIso,and(updated_at.eq.$sinceIso,id.gt.$lastId)',
        );
      } else {
        query = query.gt('updated_at', sinceIso);
      }
    }

    final response = await query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchExpenses({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    final client = _activeClient;
    debugPrint(
      '[SupabaseSync] Fetch expenses farm=$farmId, since=$since, lastId=$lastId, limit=$limit',
    );

    var query = client
        .from('expenses')
        .select()
        .eq('farm_id', farmId);

    if (since != null) {
      final sinceIso = since.toIso8601String();
      if (lastId != null && lastId.isNotEmpty) {
        query = query.or(
          'updated_at.gt.$sinceIso,and(updated_at.eq.$sinceIso,id.gt.$lastId)',
        );
      } else {
        query = query.gt('updated_at', sinceIso);
      }
    }

    final response = await query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response as List);
  }
}

/// Client de synchronisation inerte et hermétique pour le Mode Démo.
///
/// Lève une exception immédiate ou refuse formellement toute tentative
/// d'écriture ou d'appel RPC vers Supabase Cloud.
class DisabledSupabaseSyncClient implements ISupabaseSyncClient {
  const DisabledSupabaseSyncClient();

  static const String _blockedMessage =
      'Mode démo actif : toute écriture ou appel distant Supabase est strictement interdit pour garantir l\'étanchéité.';

  @override
  Future<SyncPushResult> pushAnimalRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? name,
    String? type,
    int? ageMonths,
    double? weightKg,
    String? healthStatus,
    String? imageUrl,
    DateTime? deletedAt,
  }) async {
    throw StateError(_blockedMessage);
  }

  @override
  Future<SyncPushResult> pushExpenseRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? animalId,
    String? label,
    double? amount,
    DateTime? date,
    String? category,
    DateTime? deletedAt,
  }) async {
    throw StateError(_blockedMessage);
  }

  @override
  Future<String> upsertAnimal(Map<String, dynamic> animalPayload) async {
    throw StateError(_blockedMessage);
  }

  @override
  Future<void> softDeleteAnimal({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    throw StateError(_blockedMessage);
  }

  @override
  Future<String> upsertExpense(Map<String, dynamic> expensePayload) async {
    throw StateError(_blockedMessage);
  }

  @override
  Future<void> softDeleteExpense({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    throw StateError(_blockedMessage);
  }

  @override
  Future<String?> getMemberRole({
    required String farmId,
    required String userId,
  }) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> fetchAnimals({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> fetchExpenses({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async =>
      const [];
}
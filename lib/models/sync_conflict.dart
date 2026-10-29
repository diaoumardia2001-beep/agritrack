// lib/models/sync_conflict.dart
import 'sync_queue_operation.dart';

/// Représente un conflit de synchronisation persistant dans Sembast.
/// Enregistre les versions locale et distante, les données correspondantes,
/// et les informations requises pour un arbitrage ou une résolution ultérieure.
class SyncConflict {
  final String id;
  final String farmId;
  final String operationId;
  final SyncEntityType entityType;
  final String localId;
  final String? remoteId;
  final int? expectedVersion;
  final int? serverVersion;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic>? serverData;
  final DateTime createdAt;
  final bool resolved;
  final DateTime? resolvedAt;
  final String? resolutionStrategy;

  const SyncConflict({
    required this.id,
    required this.farmId,
    required this.operationId,
    required this.entityType,
    required this.localId,
    this.remoteId,
    this.expectedVersion,
    this.serverVersion,
    required this.localPayload,
    this.serverData,
    required this.createdAt,
    this.resolved = false,
    this.resolvedAt,
    this.resolutionStrategy,
  });

  SyncConflict copyWith({
    String? id,
    String? farmId,
    String? operationId,
    SyncEntityType? entityType,
    String? localId,
    String? remoteId,
    int? expectedVersion,
    int? serverVersion,
    Map<String, dynamic>? localPayload,
    Map<String, dynamic>? serverData,
    DateTime? createdAt,
    bool? resolved,
    DateTime? resolvedAt,
    String? resolutionStrategy,
  }) {
    return SyncConflict(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      localId: localId ?? this.localId,
      remoteId: remoteId ?? this.remoteId,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      localPayload: localPayload ?? this.localPayload,
      serverData: serverData ?? this.serverData,
      createdAt: createdAt ?? this.createdAt,
      resolved: resolved ?? this.resolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionStrategy: resolutionStrategy ?? this.resolutionStrategy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmId': farmId,
      'operationId': operationId,
      'entityType': entityType.name,
      'localId': localId,
      if (remoteId != null) 'remoteId': remoteId,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
      if (serverVersion != null) 'serverVersion': serverVersion,
      'localPayload': localPayload,
      if (serverData != null) 'serverData': serverData,
      'createdAt': createdAt.toIso8601String(),
      'resolved': resolved,
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
      if (resolutionStrategy != null) 'resolutionStrategy': resolutionStrategy,
    };
  }

  factory SyncConflict.fromMap(Map<String, dynamic> map) {
    final entityTypeStr = map['entityType'] as String? ?? 'animal';
    final entityType = SyncEntityType.values.firstWhere(
      (e) => e.name == entityTypeStr,
      orElse: () => SyncEntityType.animal,
    );

    return SyncConflict(
      id: map['id'] as String,
      farmId: map['farmId'] as String,
      operationId: map['operationId'] as String? ?? '',
      entityType: entityType,
      localId: map['localId'] as String,
      remoteId: map['remoteId'] as String?,
      expectedVersion: (map['expectedVersion'] as num?)?.toInt(),
      serverVersion: (map['serverVersion'] as num?)?.toInt(),
      localPayload: Map<String, dynamic>.from(map['localPayload'] as Map? ?? {}),
      serverData: map['serverData'] != null
          ? Map<String, dynamic>.from(map['serverData'] as Map)
          : null,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      resolved: map['resolved'] as bool? ?? false,
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'] as String)
          : null,
      resolutionStrategy: map['resolutionStrategy'] as String?,
    );
  }
}

// lib/models/sync_queue_operation.dart

/// Type d'entité métier concernée par l'opération de synchronisation.
enum SyncEntityType {
  animal('animal'),
  expense('expense');

  final String value;
  const SyncEntityType(this.value);

  static SyncEntityType fromString(String? val) {
    if (val == null) return SyncEntityType.animal;
    final normalized = val.trim().toLowerCase();
    return SyncEntityType.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == normalized ||
          e.value.toLowerCase() == normalized,
      orElse: () => SyncEntityType.animal,
    );
  }
}

/// Action de mutation locale à répercuter sur le serveur distant.
enum SyncAction {
  create('create'),
  update('update'),
  delete('delete');

  final String value;
  const SyncAction(this.value);

  static SyncAction fromString(String? val) {
    if (val == null) return SyncAction.create;
    final normalized = val.trim().toLowerCase();
    return SyncAction.values.firstWhere(
      (a) =>
          a.name.toLowerCase() == normalized ||
          a.value.toLowerCase() == normalized,
      orElse: () => SyncAction.create,
    );
  }
}

/// Statut de traitement d'une opération au sein de la file locale.
enum SyncOperationStatus {
  pending('En attente'),
  inProgress('En cours'),
  error('En erreur');

  final String label;
  const SyncOperationStatus(this.label);

  static SyncOperationStatus fromString(String? val) {
    if (val == null) return SyncOperationStatus.pending;
    final normalized = val.trim().toLowerCase();
    return SyncOperationStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized,
      orElse: () => SyncOperationStatus.pending,
    );
  }
}

/// Opération persistante enregistrée dans le store local `sync_queue`.
///
/// Consigne chaque modification hors ligne devant être transmise à Supabase.
class SyncQueueOperation {
  final String id;
  final SyncEntityType entityType;
  final String localId;
  final SyncAction action;
  final String farmId;
  final String? userId;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastErrorMessage;
  final SyncOperationStatus status;
  final Map<String, dynamic>? payload;

  const SyncQueueOperation({
    required this.id,
    required this.entityType,
    required this.localId,
    required this.action,
    required this.farmId,
    this.userId,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastErrorMessage,
    this.status = SyncOperationStatus.pending,
    this.payload,
  });

  bool get isPending => status == SyncOperationStatus.pending;
  bool get isInProgress => status == SyncOperationStatus.inProgress;
  bool get hasFailed => status == SyncOperationStatus.error;

  SyncQueueOperation copyWith({
    String? id,
    SyncEntityType? entityType,
    String? localId,
    SyncAction? action,
    String? farmId,
    String? userId,
    DateTime? createdAt,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastErrorMessage,
    SyncOperationStatus? status,
    Map<String, dynamic>? payload,
    bool clearErrorMessage = false,
  }) {
    return SyncQueueOperation(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      localId: localId ?? this.localId,
      action: action ?? this.action,
      farmId: farmId ?? this.farmId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastErrorMessage: clearErrorMessage
          ? null
          : (lastErrorMessage ?? this.lastErrorMessage),
      status: status ?? this.status,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityType': entityType.name,
      'localId': localId,
      'action': action.name,
      'farmId': farmId,
      if (userId != null) 'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      if (lastAttemptAt != null)
        'lastAttemptAt': lastAttemptAt!.toIso8601String(),
      if (lastErrorMessage != null) 'lastErrorMessage': lastErrorMessage,
      'status': status.name,
      if (payload != null) 'payload': payload,
    };
  }

  factory SyncQueueOperation.fromMap(Map<String, dynamic> map) {
    final id =
        map['id'] as String? ?? 'op_${DateTime.now().microsecondsSinceEpoch}';
    final entityType = SyncEntityType.fromString(map['entityType'] as String?);
    final localId = map['localId'] as String? ?? '';
    final action = SyncAction.fromString(map['action'] as String?);
    final farmId = map['farmId'] as String? ?? '';
    final userId = map['userId'] as String?;

    final createdAtRaw = map['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    final retryCount = (map['retryCount'] as num?)?.toInt() ?? 0;

    final lastAttemptRaw = map['lastAttemptAt'];
    DateTime? lastAttemptAt;
    if (lastAttemptRaw is String) {
      lastAttemptAt = DateTime.tryParse(lastAttemptRaw);
    } else if (lastAttemptRaw is DateTime) {
      lastAttemptAt = lastAttemptRaw;
    }

    final lastErrorMessage = map['lastErrorMessage'] as String?;
    final status = SyncOperationStatus.fromString(map['status'] as String?);
    final payload = map['payload'] is Map
        ? Map<String, dynamic>.from(map['payload'] as Map)
        : null;

    return SyncQueueOperation(
      id: id,
      entityType: entityType,
      localId: localId,
      action: action,
      farmId: farmId,
      userId: userId,
      createdAt: createdAt,
      retryCount: retryCount,
      lastAttemptAt: lastAttemptAt,
      lastErrorMessage: lastErrorMessage,
      status: status,
      payload: payload,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueOperation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          entityType == other.entityType &&
          localId == other.localId &&
          action == other.action &&
          farmId == other.farmId &&
          userId == other.userId &&
          createdAt == other.createdAt &&
          retryCount == other.retryCount &&
          lastAttemptAt == other.lastAttemptAt &&
          lastErrorMessage == other.lastErrorMessage &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      entityType.hashCode ^
      localId.hashCode ^
      action.hashCode ^
      farmId.hashCode ^
      userId.hashCode ^
      createdAt.hashCode ^
      retryCount.hashCode ^
      lastAttemptAt.hashCode ^
      lastErrorMessage.hashCode ^
      status.hashCode;

  @override
  String toString() =>
      'SyncQueueOperation(id: $id, $entityType, $action, localId: $localId, farm: $farmId, status: ${status.name}, retries: $retryCount)';
}

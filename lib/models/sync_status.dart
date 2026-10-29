// lib/models/sync_status.dart

/// Représente l'état de synchronisation d'un enregistrement local avec Supabase.
enum SyncStatus {
  /// Donnée synchronisée avec succès avec le serveur distant.
  synced('Synchronisé'),

  /// Nouvel enregistrement local en attente de création sur le serveur distant.
  pendingCreate('Création en attente'),

  /// Modification locale en attente de mise à jour sur le serveur distant.
  pendingUpdate('Mise à jour en attente'),

  /// Suppression logique locale en attente de propagation sur le serveur distant.
  pendingDelete('Suppression en attente'),

  /// Échec de synchronisation nécessitant une nouvelle tentative ou une intervention.
  error('Erreur de synchronisation');

  final String label;
  const SyncStatus(this.label);

  /// Convertit une chaîne textuelle en [SyncStatus] avec repli sécurisé sur [SyncStatus.synced].
  static SyncStatus fromString(String? value) {
    if (value == null) return SyncStatus.synced;
    final normalized = value.trim().toLowerCase();
    return SyncStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized,
      orElse: () => SyncStatus.synced,
    );
  }

  /// Indique si l'entité a une mutation locale non encore confirmée par le serveur distant.
  bool get isPending =>
      this == SyncStatus.pendingCreate ||
      this == SyncStatus.pendingUpdate ||
      this == SyncStatus.pendingDelete;

  /// Indique si l'enregistrement est propre et en phase avec le serveur distant.
  bool get isSynced => this == SyncStatus.synced;
}

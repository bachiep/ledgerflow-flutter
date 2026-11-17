enum SyncStatus {
  pending,
  synced,
  failed;

  static SyncStatus fromStorage(String raw) {
    return switch (raw.toLowerCase()) {
      'synced' => SyncStatus.synced,
      'failed' => SyncStatus.failed,
      _ => SyncStatus.pending,
    };
  }

  String get storageValue => name;
}

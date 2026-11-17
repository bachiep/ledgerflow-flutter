import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';

abstract interface class RemoteSyncDataSource {
  Future<void> ensureCategories(
    List<Map<String, Object?>> categories, {
    required String userId,
  });

  Future<void> pushOutboxItem(
    SyncOutboxItem item, {
    required String userId,
  });

  Future<RemoteDeltaBatch> pullChangesSince(
    int? sinceEpochMs, {
    required String userId,
  });
}

import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';

abstract interface class SyncRepository {
  Stream<int> watchPendingOutboxCount();
  Stream<List<SyncOutboxItem>> watchOutboxItems();

  Future<Result<SyncRunSummary>> synchronize({
    required String userId,
    required bool simulateOffline,
    required bool isGuestMode,
  });
}

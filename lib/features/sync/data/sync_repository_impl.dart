import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/error/failure.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/sync/domain/network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/domain/remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl({
    required AppDatabase database,
    required RemoteSyncDataSource cloudDataSource,
    required RemoteSyncDataSource simulatedDataSource,
    required NetworkConnectivity connectivity,
    required AppClock clock,
  })  : _db = database,
        _cloudDataSource = cloudDataSource,
        _simulatedDataSource = simulatedDataSource,
        _connectivity = connectivity,
        _clock = clock;

  static const String _lastPulledAtKey = 'last_pulled_at_epoch_ms';

  final AppDatabase _db;
  final RemoteSyncDataSource _cloudDataSource;
  final RemoteSyncDataSource _simulatedDataSource;
  final NetworkConnectivity _connectivity;
  final AppClock _clock;

  @override
  Stream<int> watchPendingOutboxCount() => _db.watchPendingOutboxCount();

  @override
  Stream<List<SyncOutboxItem>> watchOutboxItems() {
    return _db.watchOutboxItems().map(
          (rows) => rows.map(_mapOutboxRow).toList(growable: false),
        );
  }

  @override
  Future<Result<SyncRunSummary>> synchronize({
    required String userId,
    required bool simulateOffline,
    required bool isGuestMode,
  }) async {
    if (simulateOffline) {
      return const Err(
        NetworkFailure(
          'Offline simulation enabled. Queued changes remain safe in SQLite outbox.',
        ),
      );
    }

    final online = await _connectivity.isOnline();
    if (!online) {
      return const Err(
        NetworkFailure('No internet connection. Outbox items kept for retry.'),
      );
    }

    final dataSource = isGuestMode ? _simulatedDataSource : _cloudDataSource;
    final pendingRows = await _db.getPendingOutboxItems();
    var pushedCount = 0;

    if (!isGuestMode) {
      try {
        final localCategories = await _db.select(_db.categories).get();
        await dataSource.ensureCategories(
          localCategories
              .map(
                (c) => <String, Object?>{
                  'id': c.id,
                  'name': c.name,
                  'type': c.type,
                  'icon_name': c.iconName,
                  'color_hex': c.colorHex,
                  'monthly_budget_minor': c.monthlyBudgetMinor,
                  'updated_at_epoch_ms': c.updatedAtEpochMs,
                },
              )
              .toList(growable: false),
          userId: userId,
        );
      } catch (error) {
        return Err(
          SyncFailure('Failed to sync categories: $error', cause: error),
        );
      }
    }

    for (final row in pendingRows) {
      final item = _mapOutboxRow(row);
      try {
        await dataSource.pushOutboxItem(item, userId: userId);
        await _db.markOutboxProcessed(
          items: [row],
          processedAtEpochMs: _clock.nowUtc().millisecondsSinceEpoch,
        );
        pushedCount++;
      } catch (error) {
        await _db.recordOutboxFailure(
          item: row,
          errorMessage: error.toString(),
        );
        return Err(
          SyncFailure(
            'Outbox push failed after $pushedCount/${pendingRows.length} items: $error',
            cause: error,
          ),
        );
      }
    }

    try {
      final rawSince = await _db.getSyncMetadata(_lastPulledAtKey);
      final sinceEpochMs = rawSince != null ? int.tryParse(rawSince) : null;
      final delta = await dataSource.pullChangesSince(
        sinceEpochMs,
        userId: userId,
      );

      final pulledCount = await _db.applyRemoteChangesLww(
        remoteWallets: delta.wallets,
        remoteTransactions: delta.transactions,
      );

      await _db.setSyncMetadata(
        _lastPulledAtKey,
        delta.serverEpochMs.toString(),
      );

      return Success(
        SyncRunSummary(
          pushedCount: pushedCount,
          pulledCount: pulledCount,
          syncedAt: _clock.nowUtc(),
        ),
      );
    } catch (error) {
      return Err(SyncFailure('Delta pull failed: $error', cause: error));
    }
  }

  SyncOutboxItem _mapOutboxRow(SyncOutboxRow row) {
    return SyncOutboxItem(
      id: row.id,
      entityType: row.entityType,
      entityId: row.entityId,
      operation: row.operation,
      payloadJson: row.payloadJson,
      attempts: row.attempts,
      lastError: row.lastError,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtEpochMs,
        isUtc: true,
      ),
      processedAt: row.processedAtEpochMs != null
          ? DateTime.fromMillisecondsSinceEpoch(
              row.processedAtEpochMs!,
              isUtc: true,
            )
          : null,
    );
  }
}

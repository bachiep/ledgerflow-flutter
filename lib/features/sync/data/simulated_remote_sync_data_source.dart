import 'dart:convert';

import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/sync/domain/remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';

/// In-memory simulated remote cloud store enabling standalone offline/guest demos.
class SimulatedRemoteSyncDataSource implements RemoteSyncDataSource {
  SimulatedRemoteSyncDataSource({
    required AppClock clock,
    this.simulatedLatency = const Duration(milliseconds: 180),
  }) : _clock = clock;

  final AppClock _clock;
  final Duration simulatedLatency;

  final Map<String, Map<String, Object?>> _remoteWallets = {};
  final Map<String, Map<String, Object?>> _remoteTransactions = {};

  Map<String, Map<String, Object?>> get remoteWallets =>
      Map.unmodifiable(_remoteWallets);
  Map<String, Map<String, Object?>> get remoteTransactions =>
      Map.unmodifiable(_remoteTransactions);

  void seedRemoteTransaction(Map<String, Object?> row) {
    final id = row['id'] as String?;
    if (id != null) {
      _remoteTransactions[id] = Map<String, Object?>.from(row);
    }
  }

  @override
  Future<void> ensureCategories(
    List<Map<String, Object?>> categories, {
    required String userId,
  }) async {}

  @override
  Future<void> pushOutboxItem(
    SyncOutboxItem item, {
    required String userId,
  }) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }
    final decoded = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final row = Map<String, Object?>.from(decoded)..['user_id'] = userId;

    if (item.entityType == 'wallet') {
      _remoteWallets[item.entityId] = row;
    } else if (item.entityType == 'transaction') {
      _remoteTransactions[item.entityId] = row;
    }
  }

  @override
  Future<RemoteDeltaBatch> pullChangesSince(
    int? sinceEpochMs, {
    required String userId,
  }) async {
    bool isAfter(Map<String, Object?> row) {
      if (sinceEpochMs == null) {
        return true;
      }
      final updated = (row['updated_at_epoch_ms'] as num?)?.toInt() ?? 0;
      return updated > sinceEpochMs;
    }

    return RemoteDeltaBatch(
      wallets: _remoteWallets.values.where(isAfter).toList(growable: false),
      transactions:
          _remoteTransactions.values.where(isAfter).toList(growable: false),
      serverEpochMs: _clock.nowUtc().millisecondsSinceEpoch,
    );
  }
}

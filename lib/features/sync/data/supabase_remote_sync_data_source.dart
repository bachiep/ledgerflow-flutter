import 'dart:convert';

import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/sync/domain/remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRemoteSyncDataSource implements RemoteSyncDataSource {
  SupabaseRemoteSyncDataSource({
    required SupabaseClient client,
    required AppClock clock,
  })  : _client = client,
        _clock = clock;

  final SupabaseClient _client;
  final AppClock _clock;

  @override
  Future<void> ensureCategories(
    List<Map<String, Object?>> categories, {
    required String userId,
  }) async {
    if (categories.isEmpty) {
      return;
    }
    final rows = categories
        .map((c) => Map<String, Object?>.from(c)..['user_id'] = userId)
        .toList(growable: false);
    await _client.from('categories').upsert(rows, onConflict: 'id');
  }

  @override
  Future<void> pushOutboxItem(
    SyncOutboxItem item, {
    required String userId,
  }) async {
    final decoded = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final payload = Map<String, Object?>.from(decoded)..['user_id'] = userId;
    final table = item.entityType == 'wallet' ? 'wallets' : 'transactions';
    await _client.from(table).upsert(payload, onConflict: 'id');
  }

  @override
  Future<RemoteDeltaBatch> pullChangesSince(
    int? sinceEpochMs, {
    required String userId,
  }) async {
    var walletQuery = _client.from('wallets').select().eq('user_id', userId);
    if (sinceEpochMs != null) {
      walletQuery = walletQuery.gt('updated_at_epoch_ms', sinceEpochMs);
    }
    final walletRows = await walletQuery;

    var txQuery = _client.from('transactions').select().eq('user_id', userId);
    if (sinceEpochMs != null) {
      txQuery = txQuery.gt('updated_at_epoch_ms', sinceEpochMs);
    }
    final txRows = await txQuery;

    return RemoteDeltaBatch(
      wallets: List<Map<String, Object?>>.from(walletRows),
      transactions: List<Map<String, Object?>>.from(txRows),
      serverEpochMs: _clock.nowUtc().millisecondsSinceEpoch,
    );
  }
}

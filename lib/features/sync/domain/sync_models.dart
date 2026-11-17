import 'package:equatable/equatable.dart';

class SyncOutboxItem extends Equatable {
  const SyncOutboxItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.attempts,
    required this.lastError,
    required this.createdAt,
    required this.processedAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? processedAt;

  bool get isProcessed => processedAt != null;
  bool get isFailed => !isProcessed && attempts > 0;
  bool get isPending => !isProcessed && attempts == 0;

  @override
  List<Object?> get props => [
        id,
        entityType,
        entityId,
        operation,
        payloadJson,
        attempts,
        lastError,
        createdAt,
        processedAt,
      ];
}

class RemoteDeltaBatch extends Equatable {
  const RemoteDeltaBatch({
    required this.wallets,
    required this.transactions,
    required this.serverEpochMs,
  });

  final List<Map<String, Object?>> wallets;
  final List<Map<String, Object?>> transactions;
  final int serverEpochMs;

  @override
  List<Object?> get props => [wallets, transactions, serverEpochMs];
}

class SyncRunSummary extends Equatable {
  const SyncRunSummary({
    required this.pushedCount,
    required this.pulledCount,
    required this.syncedAt,
  });

  final int pushedCount;
  final int pulledCount;
  final DateTime syncedAt;

  @override
  List<Object?> get props => [pushedCount, pulledCount, syncedAt];
}

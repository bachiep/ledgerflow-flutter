import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/error/failure.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/transactions/data/transaction_row_mapper.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:uuid/uuid.dart';

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository({
    required AppDatabase database,
    required AppClock clock,
    Uuid? uuid,
  })  : _db = database,
        _clock = clock,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AppClock _clock;
  final Uuid _uuid;

  @override
  Stream<List<TransactionEntry>> watchTransactions(TransactionFilter filter) {
    int? fromEpochMs;
    int? toEpochMs;
    final month = filter.month;
    if (month != null) {
      final start = DateTime.utc(month.year, month.month, 1);
      final end = DateTime.utc(month.year, month.month + 1, 1);
      fromEpochMs = start.millisecondsSinceEpoch;
      toEpochMs = end.millisecondsSinceEpoch;
    }

    return _db
        .watchActiveTransactions(
          walletId: filter.walletId,
          categoryId: filter.categoryId,
          type: filter.type?.storageValue,
          searchQuery: filter.searchQuery,
          fromEpochMs: fromEpochMs,
          toEpochMs: toEpochMs,
        )
        .map(
          (rows) =>
              rows.map(mapJoinedTransactionRow).toList(growable: false),
        );
  }

  @override
  Stream<List<CategoryItem>> watchCategories({TransactionType? type}) {
    return _db.watchCategories(type: type?.storageValue).map(
          (rows) => rows
              .map(
                (row) => CategoryItem(
                  id: row.id,
                  name: row.name,
                  type: TransactionType.fromStorage(row.type),
                  iconName: row.iconName,
                  colorHex: row.colorHex,
                  monthlyBudgetMinor: row.monthlyBudgetMinor,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<Result<String>> saveTransaction({
    String? existingId,
    required String walletId,
    required String categoryId,
    required TransactionType type,
    required int amountMinor,
    required String note,
    required DateTime occurredAt,
  }) async {
    if (amountMinor <= 0) {
      return const Err(ValidationFailure('Amount must be greater than zero.'));
    }
    if (walletId.trim().isEmpty || categoryId.trim().isEmpty) {
      return const Err(
        ValidationFailure('Wallet and category must be selected.'),
      );
    }

    try {
      final txId = (existingId != null && existingId.trim().isNotEmpty)
          ? existingId
          : _uuid.v4();
      final nowMs = _clock.nowUtc().millisecondsSinceEpoch;

      await _db.upsertTransactionAtomic(
        id: txId,
        walletId: walletId,
        categoryId: categoryId,
        type: type.storageValue,
        amountMinor: amountMinor,
        note: note.trim(),
        occurredAtEpochMs: occurredAt.toUtc().millisecondsSinceEpoch,
        updatedAtEpochMs: nowMs,
        outboxId: _uuid.v4(),
      );
      return Success(txId);
    } catch (error) {
      return Err(DatabaseFailure('Failed to save transaction.', cause: error));
    }
  }

  @override
  Future<Result<void>> softDeleteTransaction(String id) async {
    try {
      final deleted = await _db.softDeleteTransactionAtomic(
        transactionId: id,
        deletedAtEpochMs: _clock.nowUtc().millisecondsSinceEpoch,
        outboxId: _uuid.v4(),
      );
      if (!deleted) {
        return const Err(ValidationFailure('Transaction not found.'));
      }
      return const Success(null);
    } catch (error) {
      return Err(
        DatabaseFailure('Failed to delete transaction.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> restoreTransaction(String id) async {
    try {
      final restored = await _db.restoreTransactionAtomic(
        transactionId: id,
        updatedAtEpochMs: _clock.nowUtc().millisecondsSinceEpoch,
        outboxId: _uuid.v4(),
      );
      if (!restored) {
        return const Err(
          ValidationFailure('Transaction not found or already active.'),
        );
      }
      return const Success(null);
    } catch (error) {
      return Err(
        DatabaseFailure('Failed to restore transaction.', cause: error),
      );
    }
  }
}

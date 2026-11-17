import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledgerflow_flutter/core/database/connection/connection.dart';
import 'package:ledgerflow_flutter/core/database/tables/ledger_tables.dart';

part 'app_database.g.dart';

class TransactionJoinedRow {
  const TransactionJoinedRow({
    required this.transaction,
    required this.wallet,
    required this.category,
  });

  final TransactionRow transaction;
  final WalletRow wallet;
  final CategoryRow category;
}

class WalletWithBalanceRow {
  const WalletWithBalanceRow({
    required this.wallet,
    required this.currentBalanceMinor,
  });

  final WalletRow wallet;
  final int currentBalanceMinor;
}

@DriftDatabase(
  tables: [
    Wallets,
    Categories,
    Transactions,
    SyncOutbox,
    SyncMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openAppConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_active_occurred '
            'ON transactions (deleted_at_epoch_ms, occurred_at_epoch_ms DESC);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_wallet '
            'ON transactions (wallet_id, deleted_at_epoch_ms);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending '
            'ON sync_outbox (processed_at_epoch_ms, created_at_epoch_ms ASC);',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  /// Atomically inserts or updates a wallet and enqueues an outbox mutation.
  Future<void> upsertWalletAtomic({
    required String id,
    required String name,
    required String currency,
    required int initialBalanceMinor,
    required bool isShared,
    required int updatedAtEpochMs,
    required String outboxId,
  }) {
    return transaction(() async {
      await into(wallets).insertOnConflictUpdate(
        WalletsCompanion.insert(
          id: id,
          name: name,
          currency: Value(currency),
          initialBalanceMinor: Value(initialBalanceMinor),
          isShared: Value(isShared),
          updatedAtEpochMs: updatedAtEpochMs,
          deletedAtEpochMs: const Value(null),
          syncStatus: const Value('pending'),
        ),
      );

      final payload = jsonEncode({
        'id': id,
        'name': name,
        'currency': currency,
        'initial_balance_minor': initialBalanceMinor,
        'is_shared': isShared,
        'updated_at_epoch_ms': updatedAtEpochMs,
        'deleted_at_epoch_ms': null,
      });

      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          id: outboxId,
          entityType: 'wallet',
          entityId: id,
          operation: 'upsert',
          payloadJson: payload,
          createdAtEpochMs: updatedAtEpochMs,
        ),
      );
    });
  }

  /// Atomically writes a transaction and appends a `sync_outbox` record.
  Future<void> upsertTransactionAtomic({
    required String id,
    required String walletId,
    required String categoryId,
    required String type,
    required int amountMinor,
    required String note,
    required int occurredAtEpochMs,
    required int updatedAtEpochMs,
    required String outboxId,
  }) {
    return transaction(() async {
      await into(transactions).insertOnConflictUpdate(
        TransactionsCompanion.insert(
          id: id,
          walletId: walletId,
          categoryId: categoryId,
          type: type,
          amountMinor: amountMinor,
          note: Value(note),
          occurredAtEpochMs: occurredAtEpochMs,
          updatedAtEpochMs: updatedAtEpochMs,
          deletedAtEpochMs: const Value(null),
          syncStatus: const Value('pending'),
        ),
      );

      final payload = jsonEncode({
        'id': id,
        'wallet_id': walletId,
        'category_id': categoryId,
        'type': type,
        'amount_minor': amountMinor,
        'note': note,
        'occurred_at_epoch_ms': occurredAtEpochMs,
        'updated_at_epoch_ms': updatedAtEpochMs,
        'deleted_at_epoch_ms': null,
      });

      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          id: outboxId,
          entityType: 'transaction',
          entityId: id,
          operation: 'upsert',
          payloadJson: payload,
          createdAtEpochMs: updatedAtEpochMs,
        ),
      );
    });
  }

  /// Atomically soft-deletes a transaction and enqueues a tombstone outbox row.
  Future<bool> softDeleteTransactionAtomic({
    required String transactionId,
    required int deletedAtEpochMs,
    required String outboxId,
  }) {
    return transaction(() async {
      final existing = await (select(transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (existing == null || existing.deletedAtEpochMs != null) {
        return false;
      }

      await (update(transactions)..where((t) => t.id.equals(transactionId)))
          .write(
        TransactionsCompanion(
          deletedAtEpochMs: Value(deletedAtEpochMs),
          updatedAtEpochMs: Value(deletedAtEpochMs),
          syncStatus: const Value('pending'),
        ),
      );

      final payload = jsonEncode({
        'id': existing.id,
        'wallet_id': existing.walletId,
        'category_id': existing.categoryId,
        'type': existing.type,
        'amount_minor': existing.amountMinor,
        'note': existing.note,
        'occurred_at_epoch_ms': existing.occurredAtEpochMs,
        'updated_at_epoch_ms': deletedAtEpochMs,
        'deleted_at_epoch_ms': deletedAtEpochMs,
      });

      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          id: outboxId,
          entityType: 'transaction',
          entityId: transactionId,
          operation: 'delete',
          payloadJson: payload,
          createdAtEpochMs: deletedAtEpochMs,
        ),
      );
      return true;
    });
  }

  Stream<List<TransactionJoinedRow>> watchActiveTransactions({
    String? walletId,
    String? categoryId,
    String? type,
    String? searchQuery,
    int? fromEpochMs,
    int? toEpochMs,
  }) {
    final query = select(transactions).join([
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);

    query.where(transactions.deletedAtEpochMs.isNull());
    query.where(wallets.deletedAtEpochMs.isNull());

    if (walletId != null && walletId.isNotEmpty) {
      query.where(transactions.walletId.equals(walletId));
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(transactions.categoryId.equals(categoryId));
    }
    if (type != null && type.isNotEmpty) {
      query.where(transactions.type.equals(type));
    }
    if (fromEpochMs != null) {
      query.where(transactions.occurredAtEpochMs.isBiggerOrEqualValue(fromEpochMs));
    }
    if (toEpochMs != null) {
      query.where(transactions.occurredAtEpochMs.isSmallerThanValue(toEpochMs));
    }

    final normalizedSearch = searchQuery?.trim().toLowerCase() ?? '';
    if (normalizedSearch.isNotEmpty) {
      final pattern = '%$normalizedSearch%';
      query.where(
        transactions.note.lower().like(pattern) |
            categories.name.lower().like(pattern) |
            wallets.name.lower().like(pattern),
      );
    }

    query.orderBy([
      OrderingTerm.desc(transactions.occurredAtEpochMs),
      OrderingTerm.desc(transactions.updatedAtEpochMs),
    ]);

    return query.watch().map((rows) {
      return rows
          .map(
            (row) => TransactionJoinedRow(
              transaction: row.readTable(transactions),
              wallet: row.readTable(wallets),
              category: row.readTable(categories),
            ),
          )
          .toList(growable: false);
    });
  }

  Stream<List<WalletWithBalanceRow>> watchWalletsWithBalance() {
    return customSelect(
      '''
      SELECT
        w.id,
        w.name,
        w.currency,
        w.initial_balance_minor,
        w.is_shared,
        w.updated_at_epoch_ms,
        w.deleted_at_epoch_ms,
        w.sync_status,
        w.initial_balance_minor + COALESCE(SUM(
          CASE
            WHEN t.deleted_at_epoch_ms IS NULL AND t.type = 'income' THEN t.amount_minor
            WHEN t.deleted_at_epoch_ms IS NULL AND t.type = 'expense' THEN -t.amount_minor
            ELSE 0
          END
        ), 0) AS current_balance_minor
      FROM wallets w
      LEFT JOIN transactions t ON t.wallet_id = w.id
      WHERE w.deleted_at_epoch_ms IS NULL
      GROUP BY w.id
      ORDER BY w.is_shared ASC, w.name ASC
      ''',
      readsFrom: {wallets, transactions},
    ).watch().map((rows) {
      return rows.map((row) {
        final wallet = WalletRow(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          currency: row.read<String>('currency'),
          initialBalanceMinor: row.read<int>('initial_balance_minor'),
          isShared: row.read<bool>('is_shared'),
          updatedAtEpochMs: row.read<int>('updated_at_epoch_ms'),
          deletedAtEpochMs: row.readNullable<int>('deleted_at_epoch_ms'),
          syncStatus: row.read<String>('sync_status'),
        );
        return WalletWithBalanceRow(
          wallet: wallet,
          currentBalanceMinor: row.read<int>('current_balance_minor'),
        );
      }).toList(growable: false);
    });
  }

  Stream<List<CategoryRow>> watchCategories({String? type}) {
    final query = select(categories);
    if (type != null && type.isNotEmpty) {
      query.where((c) => c.type.equals(type));
    }
    query.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch();
  }

  Stream<int> watchPendingOutboxCount() {
    final countExpr = syncOutbox.id.count();
    final query = selectOnly(syncOutbox)
      ..addColumns([countExpr])
      ..where(syncOutbox.processedAtEpochMs.isNull());
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  Stream<List<SyncOutboxRow>> watchOutboxItems() {
    return (select(syncOutbox)
          ..orderBy([(o) => OrderingTerm.desc(o.createdAtEpochMs)]))
        .watch();
  }

  Future<List<SyncOutboxRow>> getPendingOutboxItems() {
    return (select(syncOutbox)
          ..where((o) => o.processedAtEpochMs.isNull())
          ..orderBy([(o) => OrderingTerm.asc(o.createdAtEpochMs)]))
        .get();
  }

  Future<void> markOutboxProcessed({
    required List<SyncOutboxRow> items,
    required int processedAtEpochMs,
  }) {
    return transaction(() async {
      for (final item in items) {
        await (update(syncOutbox)..where((o) => o.id.equals(item.id))).write(
          SyncOutboxCompanion(
            processedAtEpochMs: Value(processedAtEpochMs),
            lastError: const Value(null),
          ),
        );

        if (item.entityType == 'transaction') {
          await (update(transactions)
                ..where((t) => t.id.equals(item.entityId)))
              .write(
            const TransactionsCompanion(syncStatus: Value('synced')),
          );
        } else if (item.entityType == 'wallet') {
          await (update(wallets)..where((w) => w.id.equals(item.entityId)))
              .write(
            const WalletsCompanion(syncStatus: Value('synced')),
          );
        }
      }
    });
  }

  Future<void> recordOutboxFailure({
    required SyncOutboxRow item,
    required String errorMessage,
  }) {
    return transaction(() async {
      await (update(syncOutbox)..where((o) => o.id.equals(item.id))).write(
        SyncOutboxCompanion(
          attempts: Value(item.attempts + 1),
          lastError: Value(errorMessage),
        ),
      );

      if (item.entityType == 'transaction') {
        await (update(transactions)
              ..where((t) => t.id.equals(item.entityId)))
            .write(
          const TransactionsCompanion(syncStatus: Value('failed')),
        );
      } else if (item.entityType == 'wallet') {
        await (update(wallets)..where((w) => w.id.equals(item.entityId)))
            .write(
          const WalletsCompanion(syncStatus: Value('failed')),
        );
      }
    });
  }

  Future<String?> getSyncMetadata(String key) async {
    final row = await (select(syncMetadata)
          ..where((m) => m.metaKey.equals(key)))
        .getSingleOrNull();
    return row?.metaValue;
  }

  Future<void> setSyncMetadata(String key, String value) {
    return into(syncMetadata).insertOnConflictUpdate(
      SyncMetadataCompanion.insert(
        metaKey: key,
        metaValue: value,
      ),
    );
  }

  Future<void> clearAllData() {
    return transaction(() async {
      await delete(syncOutbox).go();
      await delete(transactions).go();
      await delete(wallets).go();
      await delete(categories).go();
      await delete(syncMetadata).go();
    });
  }
}

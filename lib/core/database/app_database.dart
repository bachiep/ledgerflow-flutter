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
    this.monthlyInflowMinor = 0,
    this.monthlyOutflowMinor = 0,
    this.monthlyTxCount = 0,
  });

  final WalletRow wallet;
  final int currentBalanceMinor;
  final int monthlyInflowMinor;
  final int monthlyOutflowMinor;
  final int monthlyTxCount;
}

class MonthlySummarySqlRow {
  const MonthlySummarySqlRow({
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.transactionCount,
  });

  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int transactionCount;
}

class CategorySpendSqlRow {
  const CategorySpendSqlRow({
    required this.categoryId,
    required this.categoryName,
    required this.iconName,
    required this.colorHex,
    required this.monthlyBudgetMinor,
    required this.spentMinor,
  });

  final String categoryId;
  final String categoryName;
  final String iconName;
  final int colorHex;
  final int monthlyBudgetMinor;
  final int spentMinor;
}

class MonthlyTrendSqlRow {
  const MonthlyTrendSqlRow({
    required this.yearMonth,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final String yearMonth;
  final int incomeMinor;
  final int expenseMinor;
}

class MonthlyAnalyticsSqlResult {
  const MonthlyAnalyticsSqlResult({
    required this.summary,
    required this.categories,
    this.sixMonthTrend = const [],
  });

  final MonthlySummarySqlRow summary;
  final List<CategorySpendSqlRow> categories;
  final List<MonthlyTrendSqlRow> sixMonthTrend;
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

  AppDatabase.forTesting(QueryExecutor executor)
      : super(
          DatabaseConnection(
            executor,
            closeStreamsSynchronously: true,
          ),
        );

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

  /// Atomically restores a soft-deleted transaction and enqueues an upsert outbox row.
  Future<bool> restoreTransactionAtomic({
    required String transactionId,
    required int updatedAtEpochMs,
    required String outboxId,
  }) {
    return transaction(() async {
      final existing = await (select(transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (existing == null || existing.deletedAtEpochMs == null) {
        return false;
      }

      await (update(transactions)..where((t) => t.id.equals(transactionId)))
          .write(
        TransactionsCompanion(
          deletedAtEpochMs: const Value(null),
          updatedAtEpochMs: Value(updatedAtEpochMs),
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
        'updated_at_epoch_ms': updatedAtEpochMs,
        'deleted_at_epoch_ms': null,
      });

      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          id: outboxId,
          entityType: 'transaction',
          entityId: transactionId,
          operation: 'upsert',
          payloadJson: payload,
          createdAtEpochMs: updatedAtEpochMs,
        ),
      );
      return true;
    });
  }

  /// Updates a category's monthly budget limit in minor units (`0` clears the cap).
  Future<bool> updateCategoryBudget({
    required String categoryId,
    required int monthlyBudgetMinor,
    required int updatedAtEpochMs,
  }) async {
    final affected = await (update(categories)
          ..where((c) => c.id.equals(categoryId)))
        .write(
      CategoriesCompanion(
        monthlyBudgetMinor: Value(monthlyBudgetMinor),
        updatedAtEpochMs: Value(updatedAtEpochMs),
      ),
    );
    return affected > 0;
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

  Stream<List<WalletWithBalanceRow>> watchWalletsWithBalance({
    int? monthFromEpochMs,
    int? monthToEpochMs,
  }) {
    final nowUtc = DateTime.now().toUtc();
    final resolvedFrom = monthFromEpochMs ??
        DateTime.utc(nowUtc.year, nowUtc.month, 1).millisecondsSinceEpoch;
    final resolvedTo = monthToEpochMs ??
        DateTime.utc(nowUtc.year, nowUtc.month + 1, 1).millisecondsSinceEpoch;

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
        ), 0) AS current_balance_minor,
        COALESCE(SUM(
          CASE
            WHEN t.deleted_at_epoch_ms IS NULL
              AND t.type = 'income'
              AND t.occurred_at_epoch_ms >= ?
              AND t.occurred_at_epoch_ms < ?
            THEN t.amount_minor
            ELSE 0
          END
        ), 0) AS monthly_inflow_minor,
        COALESCE(SUM(
          CASE
            WHEN t.deleted_at_epoch_ms IS NULL
              AND t.type = 'expense'
              AND t.occurred_at_epoch_ms >= ?
              AND t.occurred_at_epoch_ms < ?
            THEN t.amount_minor
            ELSE 0
          END
        ), 0) AS monthly_outflow_minor,
        COALESCE(SUM(
          CASE
            WHEN t.deleted_at_epoch_ms IS NULL
              AND t.occurred_at_epoch_ms >= ?
              AND t.occurred_at_epoch_ms < ?
            THEN 1
            ELSE 0
          END
        ), 0) AS monthly_tx_count
      FROM wallets w
      LEFT JOIN transactions t ON t.wallet_id = w.id
      WHERE w.deleted_at_epoch_ms IS NULL
      GROUP BY w.id
      ORDER BY w.is_shared ASC, w.name ASC
      ''',
      variables: [
        Variable.withInt(resolvedFrom),
        Variable.withInt(resolvedTo),
        Variable.withInt(resolvedFrom),
        Variable.withInt(resolvedTo),
        Variable.withInt(resolvedFrom),
        Variable.withInt(resolvedTo),
      ],
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
          monthlyInflowMinor: row.read<int>('monthly_inflow_minor'),
          monthlyOutflowMinor: row.read<int>('monthly_outflow_minor'),
          monthlyTxCount: row.read<int>('monthly_tx_count'),
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

  Stream<MonthlyAnalyticsSqlResult> watchMonthlyAnalyticsSql({
    required int fromEpochMs,
    required int toEpochMs,
    int? trendFromEpochMs,
  }) {
    final monthVariables = [
      Variable.withInt(fromEpochMs),
      Variable.withInt(toEpochMs),
    ];
    final fromDate = DateTime.fromMillisecondsSinceEpoch(fromEpochMs, isUtc: true);
    final resolvedTrendFrom = trendFromEpochMs ??
        DateTime.utc(fromDate.year, fromDate.month - 5, 1)
            .millisecondsSinceEpoch;

    return customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount_minor ELSE 0 END), 0) AS total_income_minor,
        COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount_minor ELSE 0 END), 0) AS total_expense_minor,
        COUNT(*) AS tx_count
      FROM transactions t
      INNER JOIN wallets w ON w.id = t.wallet_id
      WHERE t.deleted_at_epoch_ms IS NULL
        AND w.deleted_at_epoch_ms IS NULL
        AND t.occurred_at_epoch_ms >= ?
        AND t.occurred_at_epoch_ms < ?
      ''',
      variables: monthVariables,
      readsFrom: {transactions, wallets, categories},
    ).watchSingle().asyncMap((summaryRow) async {
      final categoryRows = await customSelect(
        '''
        SELECT
          c.id AS category_id,
          c.name AS category_name,
          c.icon_name AS icon_name,
          c.color_hex AS color_hex,
          c.monthly_budget_minor AS monthly_budget_minor,
          COALESCE(SUM(t.amount_minor), 0) AS spent_minor
        FROM transactions t
        INNER JOIN categories c ON c.id = t.category_id
        INNER JOIN wallets w ON w.id = t.wallet_id
        WHERE t.deleted_at_epoch_ms IS NULL
          AND w.deleted_at_epoch_ms IS NULL
          AND t.type = 'expense'
          AND t.occurred_at_epoch_ms >= ?
          AND t.occurred_at_epoch_ms < ?
        GROUP BY c.id
        ORDER BY spent_minor DESC, c.name ASC
        ''',
        variables: monthVariables,
        readsFrom: {transactions, wallets, categories},
      ).get();

      final trendRows = await customSelect(
        '''
        SELECT
          strftime('%Y-%m', t.occurred_at_epoch_ms / 1000, 'unixepoch') AS ym,
          COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount_minor ELSE 0 END), 0) AS income_minor,
          COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount_minor ELSE 0 END), 0) AS expense_minor
        FROM transactions t
        INNER JOIN wallets w ON w.id = t.wallet_id
        WHERE t.deleted_at_epoch_ms IS NULL
          AND w.deleted_at_epoch_ms IS NULL
          AND t.occurred_at_epoch_ms >= ?
          AND t.occurred_at_epoch_ms < ?
        GROUP BY ym
        ORDER BY ym ASC
        ''',
        variables: [
          Variable.withInt(resolvedTrendFrom),
          Variable.withInt(toEpochMs),
        ],
        readsFrom: {transactions, wallets, categories},
      ).get();

      return MonthlyAnalyticsSqlResult(
        summary: MonthlySummarySqlRow(
          totalIncomeMinor: summaryRow.read<int>('total_income_minor'),
          totalExpenseMinor: summaryRow.read<int>('total_expense_minor'),
          transactionCount: summaryRow.read<int>('tx_count'),
        ),
        categories: categoryRows
            .map(
              (row) => CategorySpendSqlRow(
                categoryId: row.read<String>('category_id'),
                categoryName: row.read<String>('category_name'),
                iconName: row.read<String>('icon_name'),
                colorHex: row.read<int>('color_hex'),
                monthlyBudgetMinor: row.read<int>('monthly_budget_minor'),
                spentMinor: row.read<int>('spent_minor'),
              ),
            )
            .toList(growable: false),
        sixMonthTrend: trendRows
            .map(
              (row) => MonthlyTrendSqlRow(
                yearMonth: row.read<String>('ym'),
                incomeMinor: row.read<int>('income_minor'),
                expenseMinor: row.read<int>('expense_minor'),
              ),
            )
            .toList(growable: false),
      );
    });
  }

  /// Merges remote delta records using deterministic Last-Write-Wins on `updatedAtEpochMs`.
  Future<int> applyRemoteChangesLww({
    required List<Map<String, Object?>> remoteWallets,
    required List<Map<String, Object?>> remoteTransactions,
  }) {
    return transaction(() async {
      var appliedCount = 0;

      for (final raw in remoteWallets) {
        final id = raw['id'] as String?;
        final remoteUpdated = (raw['updated_at_epoch_ms'] as num?)?.toInt();
        if (id == null || remoteUpdated == null) {
          continue;
        }
        final existing = await (select(wallets)
              ..where((w) => w.id.equals(id)))
            .getSingleOrNull();
        if (existing != null && existing.updatedAtEpochMs >= remoteUpdated) {
          continue;
        }

        await into(wallets).insertOnConflictUpdate(
          WalletsCompanion.insert(
            id: id,
            name: (raw['name'] as String?) ?? 'Wallet',
            currency: Value((raw['currency'] as String?) ?? 'VND'),
            initialBalanceMinor: Value(
              (raw['initial_balance_minor'] as num?)?.toInt() ?? 0,
            ),
            isShared: Value((raw['is_shared'] as bool?) ?? false),
            updatedAtEpochMs: remoteUpdated,
            deletedAtEpochMs: Value(
              (raw['deleted_at_epoch_ms'] as num?)?.toInt(),
            ),
            syncStatus: const Value('synced'),
          ),
        );
        appliedCount++;
      }

      for (final raw in remoteTransactions) {
        final id = raw['id'] as String?;
        final walletId = raw['wallet_id'] as String?;
        final categoryId = raw['category_id'] as String?;
        final remoteUpdated = (raw['updated_at_epoch_ms'] as num?)?.toInt();
        if (id == null ||
            walletId == null ||
            categoryId == null ||
            remoteUpdated == null) {
          continue;
        }

        final existing = await (select(transactions)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (existing != null && existing.updatedAtEpochMs >= remoteUpdated) {
          continue;
        }

        await into(transactions).insertOnConflictUpdate(
          TransactionsCompanion.insert(
            id: id,
            walletId: walletId,
            categoryId: categoryId,
            type: (raw['type'] as String?) ?? 'expense',
            amountMinor: (raw['amount_minor'] as num?)?.toInt() ?? 0,
            note: Value((raw['note'] as String?) ?? ''),
            occurredAtEpochMs:
                (raw['occurred_at_epoch_ms'] as num?)?.toInt() ?? remoteUpdated,
            updatedAtEpochMs: remoteUpdated,
            deletedAtEpochMs: Value(
              (raw['deleted_at_epoch_ms'] as num?)?.toInt(),
            ),
            syncStatus: const Value('synced'),
          ),
        );
        appliedCount++;
      }

      return appliedCount;
    });
  }
}

import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';

TransactionEntry mapJoinedTransactionRow(TransactionJoinedRow row) {
  return TransactionEntry(
    id: row.transaction.id,
    walletId: row.transaction.walletId,
    walletName: row.wallet.name,
    walletCurrency: row.wallet.currency,
    categoryId: row.transaction.categoryId,
    categoryName: row.category.name,
    categoryIconName: row.category.iconName,
    categoryColorHex: row.category.colorHex,
    type: TransactionType.fromStorage(row.transaction.type),
    amountMinor: row.transaction.amountMinor,
    note: row.transaction.note,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(
      row.transaction.occurredAtEpochMs,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.transaction.updatedAtEpochMs,
      isUtc: true,
    ),
    syncStatus: SyncStatus.fromStorage(row.transaction.syncStatus),
  );
}

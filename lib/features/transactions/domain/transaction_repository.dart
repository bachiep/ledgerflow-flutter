import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';

abstract interface class TransactionRepository {
  Stream<List<TransactionEntry>> watchTransactions(TransactionFilter filter);

  Stream<List<CategoryItem>> watchCategories({TransactionType? type});

  Future<Result<String>> saveTransaction({
    String? existingId,
    required String walletId,
    required String categoryId,
    required TransactionType type,
    required int amountMinor,
    required String note,
    required DateTime occurredAt,
  });

  Future<Result<void>> softDeleteTransaction(String id);
}

import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';

abstract interface class AnalyticsRepository {
  Stream<MonthlyAnalyticsSnapshot> watchMonthlyAnalytics(DateTime month);

  Future<Result<void>> updateCategoryBudget({
    required String categoryId,
    required int monthlyBudgetMinor,
  });

  Future<List<TransactionEntry>> getMonthlyTransactions(DateTime month);
}

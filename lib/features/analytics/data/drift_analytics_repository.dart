import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_repository.dart';

class DriftAnalyticsRepository implements AnalyticsRepository {
  DriftAnalyticsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<MonthlyAnalyticsSnapshot> watchMonthlyAnalytics(DateTime month) {
    final normalizedMonth = DateTime.utc(month.year, month.month, 1);
    final nextMonth = DateTime.utc(month.year, month.month + 1, 1);

    return _db
        .watchMonthlyAnalyticsSql(
          fromEpochMs: normalizedMonth.millisecondsSinceEpoch,
          toEpochMs: nextMonth.millisecondsSinceEpoch,
        )
        .map((sqlResult) {
          final totalExpense = sqlResult.summary.totalExpenseMinor;
          final spends = sqlResult.categories.map((row) {
            final ratio = totalExpense > 0 ? row.spentMinor / totalExpense : 0.0;
            return CategorySpend(
              categoryId: row.categoryId,
              categoryName: row.categoryName,
              iconName: row.iconName,
              colorHex: row.colorHex,
              spentMinor: row.spentMinor,
              monthlyBudgetMinor: row.monthlyBudgetMinor,
              shareRatio: ratio,
            );
          }).toList(growable: false);

          return MonthlyAnalyticsSnapshot(
            summary: MonthlySummary(
              month: normalizedMonth,
              totalIncomeMinor: sqlResult.summary.totalIncomeMinor,
              totalExpenseMinor: totalExpense,
              transactionCount: sqlResult.summary.transactionCount,
            ),
            categorySpends: spends,
          );
        });
  }
}

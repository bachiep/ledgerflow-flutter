import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/error/failure.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/data/transaction_row_mapper.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';

class DriftAnalyticsRepository implements AnalyticsRepository {
  DriftAnalyticsRepository(
    this._db, {
    AppClock? clock,
  }) : _clock = clock ?? const SystemClock();

  final AppDatabase _db;
  final AppClock _clock;

  @override
  Stream<MonthlyAnalyticsSnapshot> watchMonthlyAnalytics(DateTime month) {
    final normalizedMonth = DateTime.utc(month.year, month.month, 1);
    final nextMonth = DateTime.utc(month.year, month.month + 1, 1);
    final trendFrom = DateTime.utc(month.year, month.month - 5, 1);

    return _db
        .watchMonthlyAnalyticsSql(
          fromEpochMs: normalizedMonth.millisecondsSinceEpoch,
          toEpochMs: nextMonth.millisecondsSinceEpoch,
          trendFromEpochMs: trendFrom.millisecondsSinceEpoch,
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

          final trendByYm = {
            for (final item in sqlResult.sixMonthTrend) item.yearMonth: item,
          };
          final trendPoints = <MonthlyCashflowPoint>[];
          for (var offset = 5; offset >= 0; offset--) {
            final targetMonth = DateTime.utc(
              normalizedMonth.year,
              normalizedMonth.month - offset,
              1,
            );
            final ym =
                '${targetMonth.year.toString().padLeft(4, '0')}-${targetMonth.month.toString().padLeft(2, '0')}';
            final hit = trendByYm[ym];
            trendPoints.add(
              MonthlyCashflowPoint(
                month: targetMonth,
                incomeMinor: hit?.incomeMinor ?? 0,
                expenseMinor: hit?.expenseMinor ?? 0,
              ),
            );
          }

          return MonthlyAnalyticsSnapshot(
            summary: MonthlySummary(
              month: normalizedMonth,
              totalIncomeMinor: sqlResult.summary.totalIncomeMinor,
              totalExpenseMinor: totalExpense,
              transactionCount: sqlResult.summary.transactionCount,
            ),
            categorySpends: spends,
            sixMonthTrend: List<MonthlyCashflowPoint>.unmodifiable(trendPoints),
          );
        });
  }

  @override
  Future<Result<void>> updateCategoryBudget({
    required String categoryId,
    required int monthlyBudgetMinor,
  }) async {
    if (monthlyBudgetMinor < 0) {
      return const Err(
        ValidationFailure('Monthly budget limit cannot be negative.'),
      );
    }
    try {
      final updated = await _db.updateCategoryBudget(
        categoryId: categoryId,
        monthlyBudgetMinor: monthlyBudgetMinor,
        updatedAtEpochMs: _clock.nowUtc().millisecondsSinceEpoch,
      );
      if (!updated) {
        return const Err(ValidationFailure('Category not found.'));
      }
      return const Success(null);
    } catch (error) {
      return Err(
        DatabaseFailure('Failed to update monthly budget.', cause: error),
      );
    }
  }

  @override
  Future<List<TransactionEntry>> getMonthlyTransactions(DateTime month) async {
    final normalizedMonth = DateTime.utc(month.year, month.month, 1);
    final nextMonth = DateTime.utc(month.year, month.month + 1, 1);

    final rows = await _db
        .watchActiveTransactions(
          fromEpochMs: normalizedMonth.millisecondsSinceEpoch,
          toEpochMs: nextMonth.millisecondsSinceEpoch,
        )
        .first;

    final entries = rows.map(mapJoinedTransactionRow).toList(growable: false);
    entries.sort((a, b) {
      final byDate = a.occurredAt.compareTo(b.occurredAt);
      if (byDate != 0) {
        return byDate;
      }
      return a.id.compareTo(b.id);
    });
    return entries;
  }
}

import 'package:equatable/equatable.dart';

enum BudgetAlertLevel {
  none,
  onTrack,
  warning,
  exceeded,
}

class MonthlySummary extends Equatable {
  const MonthlySummary({
    required this.month,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.transactionCount,
  });

  final DateTime month;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int transactionCount;

  int get netBalanceMinor => totalIncomeMinor - totalExpenseMinor;

  @override
  List<Object?> get props => [
        month,
        totalIncomeMinor,
        totalExpenseMinor,
        transactionCount,
      ];
}

class MonthlyCashflowPoint extends Equatable {
  const MonthlyCashflowPoint({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime month;
  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;

  @override
  List<Object?> get props => [month, incomeMinor, expenseMinor];
}

class CategorySpend extends Equatable {
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.iconName,
    required this.colorHex,
    required this.spentMinor,
    required this.monthlyBudgetMinor,
    required this.shareRatio,
  });

  final String categoryId;
  final String categoryName;
  final String iconName;
  final int colorHex;
  final int spentMinor;
  final int monthlyBudgetMinor;
  final double shareRatio;

  double? get budgetUsageRatio => monthlyBudgetMinor > 0
      ? spentMinor / monthlyBudgetMinor
      : null;

  BudgetAlertLevel get alertLevel {
    final ratio = budgetUsageRatio;
    if (ratio == null) {
      return BudgetAlertLevel.none;
    }
    if (ratio >= 1.0) {
      return BudgetAlertLevel.exceeded;
    }
    if (ratio >= 0.8) {
      return BudgetAlertLevel.warning;
    }
    return BudgetAlertLevel.onTrack;
  }

  @override
  List<Object?> get props => [
        categoryId,
        categoryName,
        iconName,
        colorHex,
        spentMinor,
        monthlyBudgetMinor,
        shareRatio,
      ];
}

class MonthlyAnalyticsSnapshot extends Equatable {
  const MonthlyAnalyticsSnapshot({
    required this.summary,
    required this.categorySpends,
    this.sixMonthTrend = const [],
  });

  final MonthlySummary summary;
  final List<CategorySpend> categorySpends;
  final List<MonthlyCashflowPoint> sixMonthTrend;

  bool get isEmpty => summary.transactionCount == 0;

  @override
  List<Object?> get props => [summary, categorySpends, sixMonthTrend];
}

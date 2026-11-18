import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/widgets/budget_editor_sheet.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/widgets/cashflow_donut_chart.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/widgets/cashflow_trend_chart.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/widgets/csv_export_sheet.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/widgets/category_icon_mapper.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({
    super.key,
    this.onNavigateToLedger,
  });

  final VoidCallback? onNavigateToLedger;

  Future<void> _openCsvExport(BuildContext context, DateTime month) {
    final cubit = context.read<AnalyticsCubit>();
    return CsvExportSheet.show(
      context,
      month: month,
      loadTransactions: cubit.loadMonthlyTransactions,
    );
  }

  Future<void> _openBudgetEditor(
    BuildContext context,
    CategorySpend spend,
  ) async {
    final cubit = context.read<AnalyticsCubit>();
    await BudgetEditorSheet.show(
      context,
      spend: spend,
      onSaveBudget: (limitMinor) => cubit.updateCategoryBudget(
        categoryId: spend.categoryId,
        monthlyBudgetMinor: limitMinor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsCubit, AnalyticsState>(
      builder: (context, state) {
        return Column(
          children: [
            _MonthSelectorBar(
              month: state.month,
              onPrevious: () => context.read<AnalyticsCubit>().previousMonth(),
              onNext: () => context.read<AnalyticsCubit>().nextMonth(),
            ),
            Expanded(
              child: switch (state) {
                AnalyticsLoading() => const LoadingStateWidget(
                    message: 'Calculating monthly cashflow...',
                  ),
                AnalyticsError(:final message) => ErrorStateWidget(
                    message: message,
                    onRetry: () => context.read<AnalyticsCubit>().retry(),
                  ),
                AnalyticsEmpty(:final month) => EmptyStateWidget(
                    icon: Icons.pie_chart_outline,
                    title: 'No data for ${DateFormat.yMMMM().format(month)}',
                    subtitle:
                        'Add transactions in the Ledger tab to see monthly breakdown and budget alerts.',
                    actionLabel: onNavigateToLedger != null
                        ? 'Go to Ledger'
                        : null,
                    onAction: onNavigateToLedger,
                  ),
                AnalyticsLoaded(:final snapshot) => ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    children: [
                      _CashflowKpiRow(
                        summary: snapshot.summary,
                        onExportCsv: () => _openCsvExport(context, state.month),
                      ),
                      if (snapshot.sixMonthTrend.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        CashflowTrendChart(points: snapshot.sixMonthTrend),
                      ],
                      if (snapshot.categorySpends.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        CashflowDonutChart(
                          categorySpends: snapshot.categorySpends,
                          totalExpenseMinor: snapshot.summary.totalExpenseMinor,
                        ),
                        const SizedBox(height: 12),
                        _BudgetAlertList(
                          spends: snapshot.categorySpends,
                          onEditBudget: (spend) =>
                              _openBudgetEditor(context, spend),
                        ),
                      ],
                    ],
                  ),
              },
            ),
          ],
        );
      },
    );
  }
}

class _MonthSelectorBar extends StatelessWidget {
  const _MonthSelectorBar({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              DateFormat.yMMMM().format(month),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _CashflowKpiRow extends StatelessWidget {
  const _CashflowKpiRow({
    required this.summary,
    required this.onExportCsv,
  });

  final MonthlySummary summary;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledgerColors;
    final theme = Theme.of(context);
    final netPositive = summary.netBalanceMinor >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Cashflow (${summary.transactionCount} txns)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ).tabular,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(
                            summary.netBalanceMinor,
                            showPlusSign: netPositive,
                          ),
                          maxLines: 1,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: netPositive ? colors.income : colors.expense,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ).tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('export_csv_button'),
                  onPressed: onExportCsv,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _KpiTile(
                    icon: Icons.south_west,
                    label: 'Income',
                    amount: CurrencyFormatter.format(
                      summary.totalIncomeMinor,
                      showPlusSign: true,
                    ),
                    color: colors.income,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiTile(
                    icon: Icons.north_east,
                    label: 'Expense',
                    amount: CurrencyFormatter.format(
                      summary.totalExpenseMinor,
                      forceNegative: summary.totalExpenseMinor > 0,
                    ),
                    color: colors.expense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ).tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetAlertList extends StatelessWidget {
  const _BudgetAlertList({
    required this.spends,
    required this.onEditBudget,
  });

  final List<CategorySpend> spends;
  final ValueChanged<CategorySpend> onEditBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Category Budgets & Alerts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Tap to edit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < spends.length; i++) ...[
              _BudgetCategoryRow(
                spend: spends[i],
                colors: colors,
                onEdit: () => onEditBudget(spends[i]),
              ),
              if (i < spends.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetCategoryRow extends StatelessWidget {
  const _BudgetCategoryRow({
    required this.spend,
    required this.colors,
    required this.onEdit,
  });

  final CategorySpend spend;
  final LedgerSemanticColors colors;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = spend.budgetUsageRatio;
    final progressValue = ratio == null ? 0.0 : ratio.clamp(0.0, 1.0);

    final (statusLabel, statusColor) = switch (spend.alertLevel) {
      BudgetAlertLevel.exceeded => ('Over budget', colors.expense),
      BudgetAlertLevel.warning => ('Near limit', colors.warning),
      BudgetAlertLevel.onTrack => ('On track', colors.income),
      BudgetAlertLevel.none => ('No cap', theme.colorScheme.outline),
    };

    return InkWell(
      key: Key('budget_row_${spend.categoryId}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mapCategoryIcon(spend.iconName),
                  size: 18,
                  color: Color(spend.colorHex),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spend.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.tune_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (spend.monthlyBudgetMinor > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 8,
                  color: statusColor,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${CurrencyFormatter.format(spend.spentMinor)} / ${CurrencyFormatter.format(spend.monthlyBudgetMinor)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ).tabular,
                    ),
                  ),
                  Text(
                    '${((ratio ?? 0) * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ).tabular,
                  ),
                ],
              ),
            ] else
              Text(
                CurrencyFormatter.format(spend.spentMinor),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ).tabular,
              ),
          ],
        ),
      ),
    );
  }
}

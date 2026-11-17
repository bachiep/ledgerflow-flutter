import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/widgets/cashflow_donut_chart.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/widgets/category_icon_mapper.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({
    super.key,
    this.onNavigateToLedger,
  });

  final VoidCallback? onNavigateToLedger;

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
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      _CashflowKpiRow(summary: snapshot.summary),
                      const SizedBox(height: 12),
                      if (snapshot.categorySpends.isNotEmpty) ...[
                        CashflowDonutChart(
                          categorySpends: snapshot.categorySpends,
                          totalExpenseMinor: snapshot.summary.totalExpenseMinor,
                        ),
                        const SizedBox(height: 12),
                        _BudgetAlertList(spends: snapshot.categorySpends),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
  const _CashflowKpiRow({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledgerColors;
    final netPositive = summary.netBalanceMinor >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net Cashflow',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.format(
                summary.netBalanceMinor,
                showPlusSign: netPositive,
              ),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: netPositive ? colors.income : colors.expense,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _KpiTile(
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
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _BudgetAlertList extends StatelessWidget {
  const _BudgetAlertList({required this.spends});

  final List<CategorySpend> spends;

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
            Text(
              'Category Budgets & Alerts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < spends.length; i++) ...[
              _BudgetCategoryRow(spend: spends[i], colors: colors),
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
  });

  final CategorySpend spend;
  final LedgerSemanticColors colors;

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

    return Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  ),
                ),
              ),
              Text(
                '${((ratio ?? 0) * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ] else
          Text(
            CurrencyFormatter.format(spend.spentMinor),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

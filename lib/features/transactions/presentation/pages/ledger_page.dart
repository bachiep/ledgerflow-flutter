import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_filter_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_search_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/widgets/category_icon_mapper.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/widgets/transaction_form_sheet.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({
    super.key,
    this.onRefreshSync,
    this.clock,
  });

  final Future<void> Function()? onRefreshSync;
  final AppClock? clock;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

sealed class _LedgerListItem {
  const _LedgerListItem();
}

final class _DayHeaderItem extends _LedgerListItem {
  const _DayHeaderItem({
    required this.dayLocal,
    required this.label,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.txCount,
  });

  final DateTime dayLocal;
  final String label;
  final int incomeMinor;
  final int expenseMinor;
  final int txCount;

  int get netMinor => incomeMinor - expenseMinor;
}

final class _TransactionRowItem extends _LedgerListItem {
  const _TransactionRowItem(this.entry);

  final TransactionEntry entry;
}

class _LedgerPageState extends State<LedgerPage> {
  final TextEditingController _searchController = TextEditingController();

  AppClock get _resolvedClock =>
      widget.clock ??
      (sl.isRegistered<AppClock>() ? sl<AppClock>() : const SystemClock());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm(
    BuildContext context, {
    required List<Wallet> wallets,
    required List<CategoryItem> categories,
    TransactionEntry? editing,
  }) async {
    if (wallets.isEmpty) {
      await sl<SampleDataSeeder>().seedGuestSampleIfEmpty();
      return;
    }

    final action = await TransactionFormSheet.show(
      context,
      transactionRepository: sl<TransactionRepository>(),
      wallets: wallets,
      categories: categories,
      initialTransaction: editing,
    );
    if (action == TransactionFormAction.deleted &&
        editing != null &&
        context.mounted) {
      _showUndoSnackBar(context, editing);
    }
  }

  Future<void> _deleteWithUndo(
    BuildContext context,
    TransactionEntry entry,
  ) async {
    final cubit = context.read<TransactionsCubit>();
    final ok = await cubit.deleteTransaction(entry.id);
    if (!ok || !context.mounted) {
      return;
    }
    _showUndoSnackBar(context, entry);
  }

  void _showUndoSnackBar(BuildContext context, TransactionEntry entry) {
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<TransactionsCubit>();
    final label = entry.note.isNotEmpty ? entry.note : entry.categoryName;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('undo_delete_snackbar'),
        duration: const Duration(seconds: 5),
        content: Text(
          'Deleted "$label"',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            cubit.restoreTransaction(entry.id);
          },
        ),
      ),
    );
  }

  Future<void> _handleRefresh(BuildContext context) async {
    if (widget.onRefreshSync != null) {
      await widget.onRefreshSync!();
    } else {
      context.read<TransactionsCubit>().start();
    }
  }

  List<_LedgerListItem> _groupByDay(List<TransactionEntry> entries) {
    final nowLocal = _resolvedClock.nowUtc().toLocal();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <DateTime, List<TransactionEntry>>{};
    for (final entry in entries) {
      final local = entry.occurredAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(day, () => <TransactionEntry>[]).add(entry);
    }

    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = <_LedgerListItem>[];

    for (final day in sortedDays) {
      final dayEntries = grouped[day]!;
      var incomeMinor = 0;
      var expenseMinor = 0;
      for (final tx in dayEntries) {
        if (tx.type == TransactionType.income) {
          incomeMinor += tx.amountMinor;
        } else {
          expenseMinor += tx.amountMinor;
        }
      }

      final String label;
      if (day == today) {
        label = 'Today';
      } else if (day == yesterday) {
        label = 'Yesterday';
      } else if (day.year == today.year) {
        label = DateFormat('EEE, MMM d').format(day);
      } else {
        label = DateFormat.yMMMd().format(day);
      }

      items.add(
        _DayHeaderItem(
          dayLocal: day,
          label: label,
          incomeMinor: incomeMinor,
          expenseMinor: expenseMinor,
          txCount: dayEntries.length,
        ),
      );
      for (final tx in dayEntries) {
        items.add(_TransactionRowItem(tx));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransactionSearchBloc, String>(
      listener: (context, query) {
        context.read<TransactionFilterCubit>().setSearchQuery(query);
      },
      child: BlocBuilder<TransactionsCubit, TransactionsState>(
        builder: (context, state) {
          final filter = context.watch<TransactionFilterCubit>().state;
          final wallets = switch (state) {
            TransactionsLoaded(:final wallets) => wallets,
            TransactionsEmpty(:final wallets) => wallets,
            _ => const <Wallet>[],
          };
          final categories = switch (state) {
            TransactionsLoaded(:final categories) => categories,
            TransactionsEmpty(:final categories) => categories,
            _ => const <CategoryItem>[],
          };

          final activeWallet = filter.walletId != null
              ? wallets.cast<Wallet?>().firstWhere(
                    (w) => w?.id == filter.walletId,
                    orElse: () => null,
                  )
              : null;
          final activeWalletName = activeWallet?.name ?? 'Selected Wallet';

          return Scaffold(
            body: Column(
              children: [
                if (filter.walletId != null)
                  _ActiveWalletBanner(
                    walletName: activeWalletName,
                    onClear: () {
                      context.read<TransactionFilterCubit>().selectWallet(null);
                    },
                  ),
                if (state is TransactionsLoaded) _SummaryStrip(state: state),
                _FilterBar(
                  searchController: _searchController,
                  categories: categories,
                  activeWalletName: activeWalletName,
                ),
                Expanded(
                  child: switch (state) {
                    TransactionsLoading() => const LoadingStateWidget(),
                    TransactionsError(:final message) => ErrorStateWidget(
                        message: message,
                        onRetry: () =>
                            context.read<TransactionsCubit>().start(),
                      ),
                    TransactionsEmpty(:final hasActiveFilters) =>
                      RefreshIndicator(
                        onRefresh: () => _handleRefresh(context),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 96),
                          children: [
                            const SizedBox(height: 36),
                            EmptyStateWidget(
                              icon: Icons.receipt_long_outlined,
                              title: hasActiveFilters
                                  ? 'No matching transactions'
                                  : 'No transactions yet',
                              subtitle: hasActiveFilters
                                  ? 'Try clearing active search or category filters.'
                                  : 'Record an expense or income offline. Everything writes to SQLite first.',
                              actionLabel: hasActiveFilters
                                  ? 'Clear Filters'
                                  : 'Add Transaction',
                              onAction: () {
                                if (hasActiveFilters) {
                                  _searchController.clear();
                                  context
                                      .read<TransactionSearchBloc>()
                                      .add(const SearchCleared());
                                  context
                                      .read<TransactionFilterCubit>()
                                      .clearAll();
                                } else {
                                  _openForm(
                                    context,
                                    wallets: wallets,
                                    categories: categories,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    TransactionsLoaded(:final transactions) =>
                      Builder(
                        builder: (context) {
                          final listItems = _groupByDay(transactions);
                          return RefreshIndicator(
                            onRefresh: () => _handleRefresh(context),
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 4, 12, 96),
                              itemCount: listItems.length,
                              itemBuilder: (context, index) {
                                final item = listItems[index];
                                return switch (item) {
                                  _DayHeaderItem() => _DaySectionHeader(
                                      key: ValueKey(
                                        'day_${item.dayLocal.toIso8601String()}',
                                      ),
                                      header: item,
                                    ),
                                  _TransactionRowItem(:final entry) =>
                                    Dismissible(
                                      key: ValueKey('tx_dismiss_${entry.id}'),
                                      direction: DismissDirection.endToStart,
                                      background: const _DeleteSwipeBackground(),
                                      onDismissed: (_) =>
                                          _deleteWithUndo(context, entry),
                                      child: _TransactionCard(
                                        key: ValueKey('tx_card_${entry.id}'),
                                        entry: entry,
                                        onTap: () => _openForm(
                                          context,
                                          wallets: wallets,
                                          categories: categories,
                                          editing: entry,
                                        ),
                                        onDelete: () =>
                                            _deleteWithUndo(context, entry),
                                      ),
                                    ),
                                };
                              },
                            ),
                          );
                        },
                      ),
                  },
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              key: const Key('add_tx_fab'),
              onPressed: () => _openForm(
                context,
                wallets: wallets,
                categories: categories,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          );
        },
      ),
    );
  }
}

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({
    super.key,
    required this.header,
  });

  final _DayHeaderItem header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;
    final net = header.netMinor;
    final netPositive = net >= 0;
    final netColor = net > 0
        ? colors.income
        : net < 0
            ? colors.expense
            : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    header.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Text(
                    '${header.txCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ).tabular,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(
              net,
              showPlusSign: netPositive && net > 0,
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: netColor,
              fontWeight: FontWeight.w700,
            ).tabular,
          ),
        ],
      ),
    );
  }
}

class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    final colors = context.ledgerColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.expense.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.expense.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: colors.expense, size: 20),
          const SizedBox(width: 6),
          Text(
            'Delete',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.expense,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.state});

  final TransactionsLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Balance',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${state.transactions.length} entries',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ).tabular,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.format(state.totalWalletBalanceMinor),
                  maxLines: 1,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ).tabular,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricPill(
                      icon: Icons.south_west,
                      label: 'Income',
                      value: CurrencyFormatter.format(
                        state.filteredIncomeMinor,
                        showPlusSign: true,
                      ),
                      color: colors.income,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricPill(
                      icon: Icons.north_east,
                      label: 'Expense',
                      value: CurrencyFormatter.format(
                        state.filteredExpenseMinor,
                        forceNegative: state.filteredExpenseMinor > 0,
                      ),
                      color: colors.expense,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              value,
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

class _ActiveWalletBanner extends StatelessWidget {
  const _ActiveWalletBanner({
    required this.walletName,
    required this.onClear,
  });

  final String walletName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('active_wallet_filter_banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing: $walletName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: const Key('clear_wallet_filter_button'),
            onPressed: onClear,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: theme.colorScheme.primary,
            ),
            icon: const Icon(Icons.close, size: 14),
            label: const Text('Show All'),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.categories,
    required this.activeWalletName,
  });

  final TextEditingController searchController;
  final List<CategoryItem> categories;
  final String activeWalletName;

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<TransactionFilterCubit>().state;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(
        children: [
          TextField(
            key: const Key('ledger_search_field'),
            controller: searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search notes, categories, or wallets...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty ||
                      filter.searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        context
                            .read<TransactionSearchBloc>()
                            .add(const SearchCleared());
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              context
                  .read<TransactionSearchBloc>()
                  .add(SearchQueryChanged(value));
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter.type == null && filter.walletId == null,
                  onSelected: (_) =>
                      context.read<TransactionFilterCubit>().clearAll(),
                ),
                if (filter.walletId != null) ...[
                  const SizedBox(width: 6),
                  InputChip(
                    key: const Key('active_wallet_filter_chip'),
                    avatar: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                    ),
                    label: Text('Showing: $activeWalletName'),
                    selected: true,
                    onDeleted: () => context
                        .read<TransactionFilterCubit>()
                        .selectWallet(null),
                  ),
                ],
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: filter.type == TransactionType.expense,
                  onSelected: (_) => context
                      .read<TransactionFilterCubit>()
                      .selectType(
                        filter.type == TransactionType.expense
                            ? null
                            : TransactionType.expense,
                      ),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: filter.type == TransactionType.income,
                  onSelected: (_) => context
                      .read<TransactionFilterCubit>()
                      .selectType(
                        filter.type == TransactionType.income
                            ? null
                            : TransactionType.income,
                      ),
                ),
                const SizedBox(width: 6),
                for (final category in categories) ...[
                  FilterChip(
                    label: Text(category.name),
                    selected: filter.categoryId == category.id,
                    onSelected: (selected) => context
                        .read<TransactionFilterCubit>()
                        .selectCategory(selected ? category.id : null),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final TransactionEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledgerColors;
    final theme = Theme.of(context);
    final isExpense = entry.type == TransactionType.expense;
    final amountColor = isExpense ? colors.expense : colors.income;
    final amountText = CurrencyFormatter.format(
      entry.amountMinor,
      currency: entry.walletCurrency,
      showPlusSign: !isExpense,
      forceNegative: isExpense,
    );

    final (badgeLabel, badgeColor) = switch (entry.syncStatus) {
      SyncStatus.synced => ('SYNCED', colors.synced),
      SyncStatus.pending => ('PENDING', colors.pending),
      SyncStatus.failed => ('FAILED', colors.failed),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(entry.categoryColorHex).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  mapCategoryIcon(entry.categoryIconName),
                  size: 20,
                  color: Color(entry.categoryColorHex),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.note.isNotEmpty ? entry.note : entry.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.categoryName} • ${entry.walletName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ).tabular,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                key: Key('tx_menu_${entry.id}'),
                tooltip: 'Actions',
                onSelected: (value) {
                  if (value == 'edit') {
                    onTap();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
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
  });

  final Future<void> Function()? onRefreshSync;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final TextEditingController _searchController = TextEditingController();

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

    await TransactionFormSheet.show(
      context,
      transactionRepository: sl<TransactionRepository>(),
      wallets: wallets,
      categories: categories,
      initialTransaction: editing,
    );
  }

  Future<void> _handleRefresh(BuildContext context) async {
    if (widget.onRefreshSync != null) {
      await widget.onRefreshSync!();
    } else {
      context.read<TransactionsCubit>().start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransactionSearchBloc, String>(
      listener: (context, query) {
        context.read<TransactionFilterCubit>().setSearchQuery(query);
      },
      child: BlocBuilder<TransactionsCubit, TransactionsState>(
        builder: (context, state) {
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

          return Scaffold(
            body: Column(
              children: [
                if (state is TransactionsLoaded)
                  _SummaryStrip(state: state),
                _FilterBar(
                  searchController: _searchController,
                  categories: categories,
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
                          children: [
                            const SizedBox(height: 48),
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
                      RefreshIndicator(
                        onRefresh: () => _handleRefresh(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final entry = transactions[index];
                            return _TransactionCard(
                              entry: entry,
                              onTap: () => _openForm(
                                context,
                                wallets: wallets,
                                categories: categories,
                                editing: entry,
                              ),
                              onDelete: () => context
                                  .read<TransactionsCubit>()
                                  .deleteTransaction(entry.id),
                            );
                          },
                        ),
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
              Text(
                'Total Balance',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.format(state.totalWalletBalanceMinor),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricPill(
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
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
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
            value,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.categories,
  });

  final TextEditingController searchController;
  final List<CategoryItem> categories;

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<TransactionFilterCubit>().state;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
                    label: const Text('Wallet Filter'),
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(entry.categoryColorHex).withValues(alpha: 0.14),
                child: Icon(
                  mapCategoryIcon(entry.categoryIconName),
                  color: Color(entry.categoryColorHex),
                ),
              ),
              const SizedBox(width: 12),
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
                      '${entry.categoryName} • ${entry.walletName} • ${DateFormat.MMMd().format(entry.occurredAt.toLocal())}',
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
                    ),
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
                tooltip: 'Actions',
                onSelected: (value) {
                  if (value == 'edit') {
                    onTap();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';
import 'package:ledgerflow_flutter/features/wallets/presentation/cubit/wallets_cubit.dart';

class WalletsPage extends StatelessWidget {
  const WalletsPage({
    super.key,
    this.onWalletSelected,
  });

  final ValueChanged<Wallet>? onWalletSelected;

  Future<void> _openCreateWalletSheet(BuildContext context) {
    final walletsCubit = context.read<WalletsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => BlocProvider<WalletsCubit>.value(
        value: walletsCubit,
        child: const _CreateWalletSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<WalletsCubit, WalletsState>(
        builder: (context, state) {
          return switch (state) {
            WalletsLoading() => const LoadingStateWidget(
                message: 'Loading wallets...',
              ),
            WalletsError(:final message) => ErrorStateWidget(
                message: message,
                onRetry: () => context.read<WalletsCubit>().start(),
              ),
            WalletsEmpty() => EmptyStateWidget(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No wallets yet',
                subtitle:
                    'Create a personal or shared group wallet to track balances offline.',
                actionLabel: 'Create Wallet',
                onAction: () => _openCreateWalletSheet(context),
              ),
            WalletsLoaded(:final wallets, :final totalBalanceMinor) =>
              _WalletsLoadedView(
                wallets: wallets,
                totalBalanceMinor: totalBalanceMinor,
                onWalletSelected: onWalletSelected,
              ),
          };
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_wallet_fab'),
        onPressed: () => _openCreateWalletSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New Wallet'),
      ),
    );
  }
}

class _WalletsLoadedView extends StatelessWidget {
  const _WalletsLoadedView({
    required this.wallets,
    required this.totalBalanceMinor,
    this.onWalletSelected,
  });

  final List<Wallet> wallets;
  final int totalBalanceMinor;
  final ValueChanged<Wallet>? onWalletSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;
    final totalInflow = wallets.fold<int>(
      0,
      (sum, w) => sum + w.monthlyInflowMinor,
    );
    final totalOutflow = wallets.fold<int>(
      0,
      (sum, w) => sum + w.monthlyOutflowMinor,
    );
    final totalTxCount = wallets.fold<int>(
      0,
      (sum, w) => sum + w.monthlyTxCount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Net Balance Across Wallets',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        '${wallets.length} wallets • $totalTxCount txns',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ).tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(totalBalanceMinor),
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ).tabular,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryMetricChip(
                        icon: Icons.south_west,
                        label: 'Month Inflow',
                        value: CurrencyFormatter.format(
                          totalInflow,
                          showPlusSign: true,
                        ),
                        color: colors.income,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryMetricChip(
                        icon: Icons.north_east,
                        label: 'Month Outflow',
                        value: CurrencyFormatter.format(
                          totalOutflow,
                          forceNegative: totalOutflow > 0,
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
        const SizedBox(height: 12),
        for (final wallet in wallets)
          _WalletCard(
            key: ValueKey('wallet_card_${wallet.id}'),
            wallet: wallet,
            onTap: onWalletSelected != null
                ? () => onWalletSelected!(wallet)
                : null,
          ),
      ],
    );
  }
}

class _SummaryMetricChip extends StatelessWidget {
  const _SummaryMetricChip({
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
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
              style: theme.textTheme.titleSmall?.copyWith(
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

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    super.key,
    required this.wallet,
    this.onTap,
  });

  final Wallet wallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;
    final (badgeLabel, badgeColor) = switch (wallet.syncStatus) {
      SyncStatus.synced => ('SYNCED', colors.synced),
      SyncStatus.pending => ('PENDING', colors.pending),
      SyncStatus.failed => ('FAILED', colors.failed),
    };

    final netDelta = wallet.monthlyNetDeltaMinor;
    final netColor = netDelta > 0
        ? colors.income
        : netDelta < 0
            ? colors.expense
            : theme.colorScheme.onSurfaceVariant;
    final txLabel = wallet.monthlyTxCount == 1 ? '1 txn' : '${wallet.monthlyTxCount} txns';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: wallet.isShared
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      wallet.isShared
                          ? Icons.groups_outlined
                          : Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: wallet.isShared
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Initial: ${CurrencyFormatter.format(wallet.initialBalanceMinor, currency: wallet.currency)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ).tabular,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(
                          wallet.currentBalanceMinor,
                          currency: wallet.currency,
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ).tabular,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: wallet.isShared
                          ? theme.colorScheme.primaryContainer
                          : colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: wallet.isShared
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : colors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          wallet.isShared
                              ? Icons.groups_outlined
                              : Icons.person_outline,
                          size: 12,
                          color: wallet.isShared
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wallet.isShared ? 'Shared' : 'Personal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: wallet.isShared
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _WalletFlowCell(
                        label: 'Inflow',
                        value: CurrencyFormatter.format(
                          wallet.monthlyInflowMinor,
                          currency: wallet.currency,
                          showPlusSign: wallet.monthlyInflowMinor > 0,
                        ),
                        color: colors.income,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WalletFlowCell(
                        label: 'Outflow',
                        value: CurrencyFormatter.format(
                          wallet.monthlyOutflowMinor,
                          currency: wallet.currency,
                          forceNegative: wallet.monthlyOutflowMinor > 0,
                        ),
                        color: colors.expense,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WalletFlowCell(
                        label: 'Net Delta',
                        value: CurrencyFormatter.format(
                          netDelta,
                          currency: wallet.currency,
                          showPlusSign: netDelta > 0,
                        ),
                        color: netColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$txLabel this month',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ).tabular,
                    ),
                  ),
                  if (onTap != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Ledger',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
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

class _WalletFlowCell extends StatelessWidget {
  const _WalletFlowCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ).tabular,
          ),
        ),
      ],
    );
  }
}

class _CreateWalletSheet extends StatefulWidget {
  const _CreateWalletSheet();

  @override
  State<_CreateWalletSheet> createState() => _CreateWalletSheetState();
}

class _CreateWalletSheetState extends State<_CreateWalletSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  String _currency = 'VND';
  bool _isShared = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);

    final rawBalance = _balanceController.text.trim();
    final initialMinor = rawBalance.isEmpty || rawBalance == '0'
        ? 0
        : (CurrencyFormatter.parsePositiveMinor(
              rawBalance,
              currency: _currency,
            ) ??
            0);

    final ok = await context.read<WalletsCubit>().createWallet(
          name: _nameController.text,
          currency: _currency,
          initialBalanceMinor: initialMinor,
          isShared: _isShared,
        );
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'New Wallet',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('wallet_name_field'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Wallet name',
                          hintText: 'Travel Group Fund',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a wallet name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              key: const Key('wallet_balance_field'),
                              controller: _balanceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Initial balance',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              decoration: const InputDecoration(
                                labelText: 'Currency',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'VND',
                                  child: Text('VND'),
                                ),
                                DropdownMenuItem(
                                  value: 'USD',
                                  child: Text('USD'),
                                ),
                              ],
                              onChanged: _submitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() => _currency = value);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        key: const Key('wallet_shared_switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shared Group Wallet'),
                        subtitle: const Text(
                          'Track shared expenses for trips or roommates.',
                        ),
                        value: _isShared,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _isShared = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('wallet_submit_button'),
                onPressed: _submitting ? null : _submit,
                child: const Text('Create Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Balance Across Wallets',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(totalBalanceMinor),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final wallet in wallets)
                    _WalletCard(
                      wallet: wallet,
                      onTap: onWalletSelected != null
                          ? () => onWalletSelected!(wallet)
                          : null,
                    ),
                ],
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

class _WalletCard extends StatelessWidget {
  const _WalletCard({
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: wallet.isShared
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.primaryContainer,
                child: Icon(
                  wallet.isShared
                      ? Icons.groups_outlined
                      : Icons.account_balance_wallet_outlined,
                  color: wallet.isShared
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            wallet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (wallet.isShared) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Shared',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Initial: ${CurrencyFormatter.format(wallet.initialBalanceMinor, currency: wallet.currency)}',
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
                    CurrencyFormatter.format(
                      wallet.currentBalanceMinor,
                      currency: wallet.currency,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
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
            ],
          ),
        ),
      ),
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
                          ?.copyWith(fontWeight: FontWeight.w600),
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

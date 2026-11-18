import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';
import 'package:ledgerflow_flutter/features/wallets/presentation/cubit/wallets_cubit.dart';

class TransferModal extends StatefulWidget {
  const TransferModal({
    super.key,
    required this.wallets,
    this.initialSourceWalletId,
    this.initialDestinationWalletId,
  });

  final List<Wallet> wallets;
  final String? initialSourceWalletId;
  final String? initialDestinationWalletId;

  static Future<bool?> show(
    BuildContext context, {
    required List<Wallet> wallets,
    String? initialSourceWalletId,
    String? initialDestinationWalletId,
  }) {
    final walletsCubit = context.read<WalletsCubit>();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => BlocProvider<WalletsCubit>.value(
        value: walletsCubit,
        child: TransferModal(
          wallets: wallets,
          initialSourceWalletId: initialSourceWalletId,
          initialDestinationWalletId: initialDestinationWalletId,
        ),
      ),
    );
  }

  @override
  State<TransferModal> createState() => _TransferModalState();
}

class _TransferModalState extends State<TransferModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late String _sourceWalletId;
  late String _destinationWalletId;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wallets = widget.wallets;
    _sourceWalletId = widget.initialSourceWalletId ??
        (wallets.isNotEmpty ? wallets.first.id : '');

    final other = wallets.where((w) => w.id != _sourceWalletId).toList();
    _destinationWalletId = widget.initialDestinationWalletId ??
        (other.isNotEmpty
            ? other.first.id
            : (wallets.length > 1 ? wallets[1].id : ''));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Wallet? get _sourceWallet => widget.wallets
      .cast<Wallet?>()
      .firstWhere((w) => w?.id == _sourceWalletId, orElse: () => null);

  Wallet? get _destinationWallet => widget.wallets
      .cast<Wallet?>()
      .firstWhere((w) => w?.id == _destinationWalletId, orElse: () => null);

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_sourceWalletId == _destinationWalletId) {
      setState(() =>
          _errorMessage = 'Source and destination wallets must be different.');
      return;
    }

    final rawAmount = _amountController.text.trim();
    final amountMinor = CurrencyFormatter.parsePositiveMinor(
      rawAmount,
      currency: _sourceWallet?.currency ?? 'VND',
    );
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _errorMessage = 'Please enter an amount greater than 0.');
      return;
    }

    final sourceBal = _sourceWallet?.currentBalanceMinor ?? 0;
    if (amountMinor > sourceBal) {
      setState(() {
        _errorMessage =
            'Insufficient balance in ${_sourceWallet?.name ?? 'source wallet'} (${CurrencyFormatter.format(sourceBal)} available).';
      });
      return;
    }

    setState(() => _submitting = true);
    final result = await context.read<WalletsCubit>().transferBetweenWallets(
          sourceWalletId: _sourceWalletId,
          destinationWalletId: _destinationWalletId,
          amountMinor: amountMinor,
          note: _noteController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transferred ${CurrencyFormatter.format(amountMinor)} to ${_destinationWallet?.name ?? 'destination wallet'}',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      },
      onFailure: (failure) {
        setState(() => _errorMessage = failure.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet Transfer',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Atomic balance transfer in SQLite',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const Key('transfer_source_dropdown'),
                      initialValue:
                          _sourceWalletId.isNotEmpty ? _sourceWalletId : null,
                      decoration: InputDecoration(
                        labelText: 'From Wallet (Source)',
                        prefixIcon:
                            const Icon(Icons.account_balance_wallet_outlined),
                        helperText: _sourceWallet != null
                            ? 'Available: ${CurrencyFormatter.format(_sourceWallet!.currentBalanceMinor)}'
                            : null,
                      ),
                      items: widget.wallets.map((w) {
                        return DropdownMenuItem(
                          value: w.id,
                          child: Text(
                            '${w.name} (${CurrencyFormatter.format(w.currentBalanceMinor)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _sourceWalletId = value;
                                  _errorMessage = null;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('transfer_destination_dropdown'),
                      initialValue: _destinationWalletId.isNotEmpty
                          ? _destinationWalletId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'To Wallet (Destination)',
                        prefixIcon: Icon(Icons.call_received_outlined),
                      ),
                      items: widget.wallets.map((w) {
                        return DropdownMenuItem(
                          value: w.id,
                          child: Text(
                            '${w.name} (${CurrencyFormatter.format(w.currentBalanceMinor)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _destinationWalletId = value;
                                  _errorMessage = null;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('transfer_amount_field'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Transfer Amount',
                        prefixIcon: const Icon(Icons.attach_money_outlined),
                        hintText: 'e.g. 200,000',
                        suffixText: _sourceWallet?.currency ?? 'VND',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter transfer amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('transfer_note_field'),
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                        hintText: 'e.g., Shared dinner fund, savings rebalance',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('transfer_submit_button'),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Confirm Transfer'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

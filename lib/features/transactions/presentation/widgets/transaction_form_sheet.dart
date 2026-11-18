import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_form_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/widgets/category_icon_mapper.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';

enum TransactionFormAction {
  saved,
  deleted,
}

class TransactionFormSheet extends StatelessWidget {
  const TransactionFormSheet({
    super.key,
    required this.transactionRepository,
    required this.wallets,
    required this.categories,
    this.initialTransaction,
    this.initialDate,
  });

  final TransactionRepository transactionRepository;
  final List<Wallet> wallets;
  final List<CategoryItem> categories;
  final TransactionEntry? initialTransaction;
  final DateTime? initialDate;

  static Future<TransactionFormAction?> show(
    BuildContext context, {
    required TransactionRepository transactionRepository,
    required List<Wallet> wallets,
    required List<CategoryItem> categories,
    TransactionEntry? initialTransaction,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet<TransactionFormAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => TransactionFormSheet(
        transactionRepository: transactionRepository,
        wallets: wallets,
        categories: categories,
        initialTransaction: initialTransaction,
        initialDate: initialDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionFormCubit>(
      create: (_) => TransactionFormCubit(transactionRepository),
      child: _TransactionFormBody(
        transactionRepository: transactionRepository,
        wallets: wallets,
        categories: categories,
        initialTransaction: initialTransaction,
        initialDate: initialDate,
      ),
    );
  }
}

class _TransactionFormBody extends StatefulWidget {
  const _TransactionFormBody({
    required this.transactionRepository,
    required this.wallets,
    required this.categories,
    this.initialTransaction,
    this.initialDate,
  });

  final TransactionRepository transactionRepository;
  final List<Wallet> wallets;
  final List<CategoryItem> categories;
  final TransactionEntry? initialTransaction;
  final DateTime? initialDate;

  @override
  State<_TransactionFormBody> createState() => _TransactionFormBodyState();
}

class _TransactionFormBodyState extends State<_TransactionFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late TransactionType _type;
  late String _selectedWalletId;
  late String _selectedCategoryId;
  late DateTime _occurredAt;

  @override
  void initState() {
    super.initState();
    final editing = widget.initialTransaction;
    _type = editing?.type ?? TransactionType.expense;
    _selectedWalletId = editing?.walletId ??
        (widget.wallets.isNotEmpty ? widget.wallets.first.id : '');
    _occurredAt =
        editing?.occurredAt.toLocal() ?? (widget.initialDate ?? DateTime.now());

    final matchingCategories = _categoriesForType(_type);
    _selectedCategoryId = editing?.categoryId ??
        (matchingCategories.isNotEmpty ? matchingCategories.first.id : '');

    _amountController = TextEditingController(
      text: editing != null
          ? CurrencyFormatter.formatEditableInput(
              editing.amountMinor,
              currency: editing.walletCurrency,
            )
          : '',
    );
    _noteController = TextEditingController(text: editing?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<CategoryItem> _categoriesForType(TransactionType type) {
    return widget.categories
        .where((c) => c.type == type)
        .toList(growable: false);
  }

  Wallet? get _selectedWallet {
    for (final wallet in widget.wallets) {
      if (wallet.id == _selectedWalletId) {
        return wallet;
      }
    }
    return widget.wallets.isNotEmpty ? widget.wallets.first : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _deleteEditing() async {
    final editing = widget.initialTransaction;
    if (editing == null) {
      return;
    }
    final result =
        await widget.transactionRepository.softDeleteTransaction(editing.id);
    if (!mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(TransactionFormAction.deleted),
      onFailure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final currency = _selectedWallet?.currency ?? 'VND';
    final amountMinor = CurrencyFormatter.parsePositiveMinor(
      _amountController.text,
      currency: currency,
    );
    if (amountMinor == null) {
      return;
    }

    context.read<TransactionFormCubit>().submit(
          existingId: widget.initialTransaction?.id,
          walletId: _selectedWalletId,
          categoryId: _selectedCategoryId,
          type: _type,
          amountMinor: amountMinor,
          note: _noteController.text,
          occurredAt: _occurredAt.toUtc(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final filteredCategories = _categoriesForType(_type);
    final currency = _selectedWallet?.currency ?? 'VND';
    final isEditing = widget.initialTransaction != null;
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: BlocConsumer<TransactionFormCubit, TransactionFormState>(
        listener: (context, state) {
          if (state is TransactionFormSuccess) {
            Navigator.of(context).pop(TransactionFormAction.saved);
          } else if (state is TransactionFormFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state is TransactionFormSubmitting;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + viewInsets.bottom,
            ),
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
                          isEditing ? 'Edit Transaction' : 'New Transaction',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isEditing)
                        IconButton(
                          key: const Key('tx_delete_button'),
                          tooltip: 'Delete transaction',
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: isSubmitting ? null : _deleteEditing,
                        ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
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
                          SegmentedButton<TransactionType>(
                            segments: const [
                              ButtonSegment(
                                value: TransactionType.expense,
                                label: Text('Expense'),
                                icon: Icon(Icons.north_east, size: 18),
                              ),
                              ButtonSegment(
                                value: TransactionType.income,
                                label: Text('Income'),
                                icon: Icon(Icons.south_west, size: 18),
                              ),
                            ],
                            selected: {_type},
                            onSelectionChanged: isSubmitting
                                ? null
                                : (selection) {
                                    final nextType = selection.first;
                                    final nextCats =
                                        _categoriesForType(nextType);
                                    setState(() {
                                      _type = nextType;
                                      if (nextCats.isNotEmpty) {
                                        _selectedCategoryId = nextCats.first.id;
                                      }
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('tx_amount_field'),
                            controller: _amountController,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ).tabular,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount ($currency)',
                              hintText: currency == 'VND' ? '150000' : '12.50',
                              prefixIcon: const Icon(Icons.payments_outlined),
                            ),
                            validator: (value) {
                              final parsed =
                                  CurrencyFormatter.parsePositiveMinor(
                                value ?? '',
                                currency: currency,
                              );
                              if (parsed == null) {
                                return 'Enter a valid positive amount';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          if (widget.wallets.isNotEmpty)
                            DropdownButtonFormField<String>(
                              key: ValueKey('wallet_$_selectedWalletId'),
                              initialValue: _selectedWalletId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Wallet',
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              items: widget.wallets
                                  .map(
                                    (wallet) => DropdownMenuItem<String>(
                                      value: wallet.id,
                                      child: Text(
                                        wallet.isShared
                                            ? '${wallet.name} (Shared)'
                                            : wallet.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: isSubmitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(
                                          () => _selectedWalletId = value,
                                        );
                                      }
                                    },
                            ),
                          const SizedBox(height: 12),
                          if (filteredCategories.isNotEmpty)
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'cat_${_type.name}_$_selectedCategoryId',
                              ),
                              initialValue: filteredCategories
                                      .any((c) => c.id == _selectedCategoryId)
                                  ? _selectedCategoryId
                                  : filteredCategories.first.id,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: filteredCategories
                                  .map(
                                    (cat) => DropdownMenuItem<String>(
                                      value: cat.id,
                                      child: Row(
                                        children: [
                                          Icon(
                                            mapCategoryIcon(cat.iconName),
                                            size: 18,
                                            color: Color(cat.colorHex),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              cat.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: isSubmitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(
                                          () => _selectedCategoryId = value,
                                        );
                                      }
                                    },
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('tx_note_field'),
                            controller: _noteController,
                            maxLength: 140,
                            decoration: const InputDecoration(
                              labelText: 'Note (optional)',
                              hintText: 'Lunch, coffee, utilities...',
                              prefixIcon: Icon(Icons.notes_outlined),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: isSubmitting ? null : _pickDate,
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                            ),
                            label: Text(
                              'Date: ${DateFormat.yMMMd().format(_occurredAt)}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('tx_submit_button'),
                    onPressed:
                        isSubmitting || widget.wallets.isEmpty ? null : _onSubmit,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Save Transaction'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

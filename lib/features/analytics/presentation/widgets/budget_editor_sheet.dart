import 'package:flutter/material.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/widgets/category_icon_mapper.dart';

class BudgetEditorSheet extends StatefulWidget {
  const BudgetEditorSheet({
    super.key,
    required this.spend,
    required this.onSaveBudget,
    this.currency = 'VND',
  });

  final CategorySpend spend;
  final Future<Result<void>> Function(int monthlyBudgetMinor) onSaveBudget;
  final String currency;

  static Future<bool?> show(
    BuildContext context, {
    required CategorySpend spend,
    required Future<Result<void>> Function(int monthlyBudgetMinor) onSaveBudget,
    String currency = 'VND',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => BudgetEditorSheet(
        spend: spend,
        onSaveBudget: onSaveBudget,
        currency: currency,
      ),
    );
  }

  @override
  State<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<BudgetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _budgetController;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialMinor = widget.spend.monthlyBudgetMinor;
    _budgetController = TextEditingController(
      text: initialMinor > 0
          ? CurrencyFormatter.formatEditableInput(
              initialMinor,
              currency: widget.currency,
            )
          : '0',
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  int? _parseBudgetOrZero(String raw) {
    final trimmed = raw.trim();
    if (trimmed == '0') {
      return 0;
    }
    return CurrencyFormatter.parsePositiveMinor(
      trimmed,
      currency: widget.currency,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final parsed = _parseBudgetOrZero(_budgetController.text);
    if (parsed == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await widget.onSaveBudget(parsed);
    if (!mounted) {
      return;
    }

    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(true),
      onFailure: (failure) {
        setState(() {
          _submitting = false;
          _errorMessage = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final spend = widget.spend;

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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(spend.colorHex).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      mapCategoryIcon(spend.iconName),
                      color: Color(spend.colorHex),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Monthly Budget',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          spend.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spent this month',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(
                                spend.spentMinor,
                                currency: widget.currency,
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ).tabular,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('budget_amount_field'),
                        controller: _budgetController,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ).tabular,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Monthly cap (${widget.currency})',
                          helperText: 'Enter 0 to remove budget cap.',
                          prefixIcon: const Icon(Icons.tune_outlined),
                        ),
                        validator: (value) {
                          if (_parseBudgetOrZero(value ?? '') == null) {
                            return 'Enter 0 or a valid positive limit';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('No Cap (0)'),
                            onPressed: _submitting
                                ? null
                                : () => _budgetController.text = '0',
                          ),
                          if (spend.spentMinor > 0)
                            ActionChip(
                              label: const Text('Set +20% Buffer'),
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      final buffered =
                                          (spend.spentMinor * 1.2).round();
                                      _budgetController.text =
                                          CurrencyFormatter.formatEditableInput(
                                        buffered,
                                        currency: widget.currency,
                                      );
                                    },
                            ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.expense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('save_budget_button'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save Budget Limit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

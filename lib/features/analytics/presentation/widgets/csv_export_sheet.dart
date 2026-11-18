import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/csv_statement_exporter.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';

class CsvExportSheet extends StatefulWidget {
  const CsvExportSheet({
    super.key,
    required this.month,
    required this.loadTransactions,
  });

  final DateTime month;
  final Future<List<TransactionEntry>> Function() loadTransactions;

  static Future<void> show(
    BuildContext context, {
    required DateTime month,
    required Future<List<TransactionEntry>> Function() loadTransactions,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => CsvExportSheet(
        month: month,
        loadTransactions: loadTransactions,
      ),
    );
  }

  @override
  State<CsvExportSheet> createState() => _CsvExportSheetState();
}

class _CsvExportSheetState extends State<CsvExportSheet> {
  CsvStatementResult? _result;
  String? _error;
  bool _loading = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.loadTransactions();
      if (!mounted) {
        return;
      }
      setState(() {
        _result = CsvStatementExporter.build(entries);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    final res = _result;
    if (res == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: res.csvContent));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${res.rowCount} CSV rows to clipboard'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    final monthLabel = DateFormat.yMMMM().format(widget.month);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.table_view_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline CSV Statement',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          monthLabel,
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const SizedBox(
                  height: 160,
                  child: LoadingStateWidget(
                    message: 'Building RFC-4180 CSV statement...',
                  ),
                )
              else if (_error != null)
                SizedBox(
                  height: 200,
                  child: ErrorStateWidget(
                    message: _error!,
                    onRetry: _load,
                  ),
                )
              else if (_result == null || _result!.rowCount == 0)
                const SizedBox(
                  height: 200,
                  child: EmptyStateWidget(
                    icon: Icons.description_outlined,
                    title: 'No rows to export',
                    subtitle:
                        'Add transactions for this month to generate an offline CSV statement.',
                    padding: EdgeInsets.all(16),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.income.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.income.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                        color: colors.income,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_result!.rowCount} rows • RFC-4180 • Formula-injection protected',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.income,
                            fontWeight: FontWeight.w600,
                          ).tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: Container(
                    key: const Key('csv_preview_box'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _result!.lines.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  _result!.lines[i],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    fontWeight: i == 0
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: i == 0
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('copy_csv_button'),
                  onPressed: _copyToClipboard,
                  icon: Icon(
                    _copied ? Icons.check_circle_outline : Icons.copy_all_outlined,
                  ),
                  label: Text(
                    _copied
                        ? 'Copied ${_result!.rowCount} Rows to Clipboard'
                        : 'Copy CSV to Clipboard',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

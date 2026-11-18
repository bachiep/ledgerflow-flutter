import 'package:intl/intl.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';

class CsvStatementResult {
  const CsvStatementResult({
    required this.csvContent,
    required this.lines,
    required this.rowCount,
  });

  final String csvContent;
  final List<String> lines;
  final int rowCount;
}

/// Builds RFC-4180 compliant offline CSV statements with formula-injection neutralization.
final class CsvStatementExporter {
  CsvStatementExporter._();

  static const String headerRow =
      'Date,Type,Category,Wallet,Note,Amount,Currency,SyncStatus';

  static final Set<String> _formulaPrefixes = {'=', '+', '-', '@', '\t', '\r'};

  /// Neutralizes spreadsheet formula prefixes (`=`, `+`, `-`, `@`) and applies RFC-4180 quoting.
  static String escapeField(String raw) {
    final trimmedLeft = raw.trimLeft();
    final needsNeutralize = raw.isNotEmpty &&
        (_formulaPrefixes.contains(raw[0]) ||
            (trimmedLeft.isNotEmpty &&
                _formulaPrefixes.contains(trimmedLeft[0])));
    final safeValue = needsNeutralize ? "'$raw" : raw;

    final requiresQuoting = safeValue.contains(',') ||
        safeValue.contains('"') ||
        safeValue.contains('\n') ||
        safeValue.contains('\r');
    if (!requiresQuoting) {
      return safeValue;
    }
    final doubledQuotes = safeValue.replaceAll('"', '""');
    return '"$doubledQuotes"';
  }

  static CsvStatementResult build(List<TransactionEntry> entries) {
    final sorted = List<TransactionEntry>.from(entries)
      ..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final lines = <String>[headerRow];

    for (final entry in sorted) {
      final dateStr = '${dateFmt.format(entry.occurredAt.toUtc())} UTC';
      final amountStr = CurrencyFormatter.formatEditableInput(
        entry.amountMinor,
        currency: entry.walletCurrency,
      );
      final fields = [
        escapeField(dateStr),
        escapeField(entry.type.storageValue),
        escapeField(entry.categoryName),
        escapeField(entry.walletName),
        escapeField(entry.note),
        escapeField(amountStr),
        escapeField(entry.walletCurrency),
        escapeField(entry.syncStatus.name),
      ];
      lines.add(fields.join(','));
    }

    return CsvStatementResult(
      csvContent: lines.join('\r\n'),
      lines: List<String>.unmodifiable(lines),
      rowCount: sorted.length,
    );
  }
}

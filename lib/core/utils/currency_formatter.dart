import 'package:intl/intl.dart';

/// Formats and parses monetary amounts stored strictly as integer minor units.
final class CurrencyFormatter {
  CurrencyFormatter._();

  static const Map<String, int> _decimalDigitsByCurrency = {
    'VND': 0,
    'JPY': 0,
    'KRW': 0,
  };

  static int decimalDigitsFor(String currency) {
    return _decimalDigitsByCurrency[currency.toUpperCase()] ?? 2;
  }

  static String symbolFor(String currency) {
    return switch (currency.toUpperCase()) {
      'VND' => '₫',
      'USD' => r'$',
      'EUR' => '€',
      _ => currency.toUpperCase(),
    };
  }

  static String format(
    int amountMinor, {
    String currency = 'VND',
    bool showPlusSign = false,
    bool forceNegative = false,
  }) {
    final normalized = currency.toUpperCase();
    final digits = decimalDigitsFor(normalized);
    final divisor = _pow10(digits);
    final isNeg = forceNegative || amountMinor < 0;
    final absMinor = amountMinor.abs();

    final formatter = NumberFormat.currency(
      locale: normalized == 'VND' ? 'vi_VN' : 'en_US',
      symbol: symbolFor(normalized),
      decimalDigits: digits,
    );

    final formattedValue = formatter.format(absMinor / divisor).trim();
    if (isNeg) {
      return '-$formattedValue';
    }
    if (showPlusSign && absMinor > 0) {
      return '+$formattedValue';
    }
    return formattedValue;
  }

  /// Formats an integer minor-unit amount for prefilling text input fields.
  static String formatEditableInput(
    int amountMinor, {
    String currency = 'VND',
  }) {
    final digits = decimalDigitsFor(currency);
    if (digits == 0) {
      return amountMinor.toString();
    }
    return (amountMinor / _pow10(digits)).toStringAsFixed(digits);
  }

  /// Formats compact chart axis values (for example `14.5M` or `540K`).
  static String formatCompactAxis(
    int amountMinor, {
    String currency = 'VND',
  }) {
    final normalized = currency.toUpperCase();
    final digits = decimalDigitsFor(normalized);
    final value = amountMinor / _pow10(digits);
    final absVal = value.abs();
    final prefix = value < 0 ? '-' : '';
    final symbol = normalized == 'VND' ? '' : symbolFor(normalized);

    String compact(double numVal, String suffix) {
      final rounded = numVal >= 10 || numVal == numVal.roundToDouble()
          ? numVal.toStringAsFixed(0)
          : numVal.toStringAsFixed(1);
      final clean = rounded.endsWith('.0')
          ? rounded.substring(0, rounded.length - 2)
          : rounded;
      return '$prefix$symbol$clean$suffix';
    }

    if (absVal >= 1000000000) {
      return compact(absVal / 1000000000, 'B');
    }
    if (absVal >= 1000000) {
      return compact(absVal / 1000000, 'M');
    }
    if (absVal >= 1000) {
      return compact(absVal / 1000, 'K');
    }
    return '$prefix$symbol${absVal.round()}';
  }

  /// Parses user-entered currency strings into positive integer minor units.
  /// Returns null when the input is empty, non-numeric, or <= 0.
  static int? parsePositiveMinor(String rawInput, {String currency = 'VND'}) {
    final trimmed = rawInput.trim().replaceAll(' ', '');
    if (trimmed.isEmpty) {
      return null;
    }

    final digits = decimalDigitsFor(currency);
    if (digits == 0) {
      final cleaned = trimmed.replaceAll(RegExp(r'[.,_]'), '');
      final parsed = int.tryParse(cleaned);
      if (parsed == null || parsed <= 0) {
        return null;
      }
      return parsed;
    }

    final cleaned = trimmed.replaceAll(',', '');
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      return null;
    }
    final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (whole == null || whole < 0) {
      return null;
    }
    var fraction = 0;
    if (parts.length == 2) {
      final fracStr = parts[1];
      if (fracStr.length > digits || !RegExp(r'^\d*$').hasMatch(fracStr)) {
        return null;
      }
      final padded = fracStr.padRight(digits, '0');
      fraction = int.tryParse(padded) ?? -1;
      if (fraction < 0) {
        return null;
      }
    }
    final total = whole * _pow10(digits) + fraction;
    return total > 0 ? total : null;
  }

  static int _pow10(int exp) {
    var result = 1;
    for (var i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }
}

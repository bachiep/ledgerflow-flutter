import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/error/failure.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';

void main() {
  group('Result<T>', () {
    test('fold handles Success and Err exhaustively', () {
      const Result<int> ok = Success(42);
      const Result<int> err = Err(ValidationFailure('Amount must be > 0'));

      expect(ok.isSuccess, isTrue);
      expect(ok.valueOrNull, 42);
      expect(ok.failureOrNull, isNull);
      expect(
        ok.fold(onSuccess: (v) => 'ok:$v', onFailure: (f) => f.message),
        'ok:42',
      );

      expect(err.isFailure, isTrue);
      expect(err.valueOrNull, isNull);
      expect(err.failureOrNull, isA<ValidationFailure>());
      expect(
        err.fold(onSuccess: (v) => 'ok:$v', onFailure: (f) => f.message),
        'Amount must be > 0',
      );
    });
  });

  group('CurrencyFormatter', () {
    test('parses and formats VND integer minor units without rounding drift', () {
      expect(CurrencyFormatter.parsePositiveMinor('150,000'), 150000);
      expect(CurrencyFormatter.parsePositiveMinor('45.500'), 45500);
      expect(CurrencyFormatter.parsePositiveMinor('0'), isNull);
      expect(CurrencyFormatter.parsePositiveMinor('-100'), isNull);
      expect(CurrencyFormatter.parsePositiveMinor('abc'), isNull);

      expect(CurrencyFormatter.format(150000, showPlusSign: true), contains('+'));
      expect(
        CurrencyFormatter.format(150000, forceNegative: true),
        startsWith('-'),
      );
    });

    test('parses USD decimal strings into exact integer cents', () {
      expect(
        CurrencyFormatter.parsePositiveMinor('12.34', currency: 'USD'),
        1234,
      );
      expect(
        CurrencyFormatter.parsePositiveMinor('10.5', currency: 'USD'),
        1050,
      );
      expect(
        CurrencyFormatter.parsePositiveMinor('10.555', currency: 'USD'),
        isNull,
      );
    });
  });

  group('FixedClock', () {
    test('advances deterministically in UTC', () {
      final clock = FixedClock(DateTime.utc(2026, 11, 18, 10, 0));
      expect(clock.nowUtc(), DateTime.utc(2026, 11, 18, 10, 0));
      clock.advance(const Duration(minutes: 15));
      expect(clock.nowUtc(), DateTime.utc(2026, 11, 18, 10, 15));
    });
  });
}

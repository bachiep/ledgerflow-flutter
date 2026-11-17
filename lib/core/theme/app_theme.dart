import 'package:flutter/material.dart';

/// Semantic theme colors for income, expense, warning, and sync badges.
@immutable
final class LedgerSemanticColors extends ThemeExtension<LedgerSemanticColors> {
  const LedgerSemanticColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.synced,
    required this.pending,
    required this.failed,
  });

  final Color income;
  final Color expense;
  final Color warning;
  final Color synced;
  final Color pending;
  final Color failed;

  static const light = LedgerSemanticColors(
    income: Color(0xFF0F766E),
    expense: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    synced: Color(0xFF15803D),
    pending: Color(0xFFB45309),
    failed: Color(0xFFB91C1C),
  );

  static const dark = LedgerSemanticColors(
    income: Color(0xFF2DD4BF),
    expense: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    synced: Color(0xFF4ADE80),
    pending: Color(0xFFFBBF24),
    failed: Color(0xFFF87171),
  );

  @override
  LedgerSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? synced,
    Color? pending,
    Color? failed,
  }) {
    return LedgerSemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      synced: synced ?? this.synced,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
    );
  }

  @override
  LedgerSemanticColors lerp(
    covariant ThemeExtension<LedgerSemanticColors>? other,
    double t,
  ) {
    if (other is! LedgerSemanticColors) {
      return this;
    }
    return LedgerSemanticColors(
      income: Color.lerp(income, other.income, t) ?? income,
      expense: Color.lerp(expense, other.expense, t) ?? expense,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      synced: Color.lerp(synced, other.synced, t) ?? synced,
      pending: Color.lerp(pending, other.pending, t) ?? pending,
      failed: Color.lerp(failed, other.failed, t) ?? failed,
    );
  }
}

extension LedgerThemeExtension on BuildContext {
  LedgerSemanticColors get ledgerColors =>
      Theme.of(this).extension<LedgerSemanticColors>() ??
      LedgerSemanticColors.light;
}

final class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF0F766E);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F9FA),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: const [LedgerSemanticColors.light],
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: const [LedgerSemanticColors.dark],
    );
  }
}

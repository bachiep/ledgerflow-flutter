import 'package:flutter/material.dart';

/// Semantic theme colors and Swiss Fintech surface tokens.
@immutable
final class LedgerSemanticColors extends ThemeExtension<LedgerSemanticColors> {
  const LedgerSemanticColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.synced,
    required this.pending,
    required this.failed,
    this.border = const Color(0xFFE2E8F0),
    this.surfaceCard = const Color(0xFFFFFFFF),
    this.surfaceSubtle = const Color(0xFFF1F5F9),
  });

  final Color income;
  final Color expense;
  final Color warning;
  final Color synced;
  final Color pending;
  final Color failed;
  final Color border;
  final Color surfaceCard;
  final Color surfaceSubtle;

  static const light = LedgerSemanticColors(
    income: Color(0xFF059669),
    expense: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    synced: Color(0xFF059669),
    pending: Color(0xFFD97706),
    failed: Color(0xFFDC2626),
    border: Color(0xFFE2E8F0),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF1F5F9),
  );

  static const dark = LedgerSemanticColors(
    income: Color(0xFF34D399),
    expense: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    synced: Color(0xFF34D399),
    pending: Color(0xFFFBBF24),
    failed: Color(0xFFF87171),
    border: Color(0xFF1E293B),
    surfaceCard: Color(0xFF111827),
    surfaceSubtle: Color(0xFF161F30),
  );

  @override
  LedgerSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? synced,
    Color? pending,
    Color? failed,
    Color? border,
    Color? surfaceCard,
    Color? surfaceSubtle,
  }) {
    return LedgerSemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      synced: synced ?? this.synced,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      border: border ?? this.border,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
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
      border: Color.lerp(border, other.border, t) ?? border,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      surfaceSubtle:
          Color.lerp(surfaceSubtle, other.surfaceSubtle, t) ?? surfaceSubtle,
    );
  }
}

extension LedgerThemeExtension on BuildContext {
  LedgerSemanticColors get ledgerColors =>
      Theme.of(this).extension<LedgerSemanticColors>() ??
      LedgerSemanticColors.light;
}

extension LedgerTextStyleExtension on TextStyle {
  TextStyle get tabular => copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

final class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color primaryBlueDark = Color(0xFF2563EB);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color darkOledBackground = Color(0xFF090D16);

  static ThemeData light() {
    const semantics = LedgerSemanticColors.light;
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFDBEAFE),
      onPrimaryContainer: Color(0xFF1E3A8A),
      secondary: Color(0xFF334155),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE2E8F0),
      onSecondaryContainer: Color(0xFF0F172A),
      tertiary: Color(0xFF059669),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFD1FAE5),
      onTertiaryContainer: Color(0xFF065F46),
      error: Color(0xFFDC2626),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF991B1B),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0F172A),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: lightBackground,
      surfaceContainer: Color(0xFFF1F5F9),
      surfaceContainerHigh: Color(0xFFE2E8F0),
      surfaceContainerHighest: Color(0xFFCBD5E1),
      onSurfaceVariant: Color(0xFF475569),
      outline: Color(0xFF94A3B8),
      outlineVariant: Color(0xFFE2E8F0),
      shadow: Color(0xFF0F172A),
      scrim: Color(0xFF0F172A),
      inverseSurface: Color(0xFF0F172A),
      onInverseSurface: Color(0xFFF8FAFC),
      inversePrimary: Color(0xFF93C5FD),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      semantics: semantics,
      scaffoldBackground: lightBackground,
      buttonPrimary: primaryBlue,
      buttonForeground: Colors.white,
    );
  }

  static ThemeData dark() {
    const semantics = LedgerSemanticColors.dark;
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF60A5FA),
      onPrimary: darkOledBackground,
      primaryContainer: Color(0xFF1E3A8A),
      onPrimaryContainer: Color(0xFFDBEAFE),
      secondary: Color(0xFF94A3B8),
      onSecondary: darkOledBackground,
      secondaryContainer: Color(0xFF1E293B),
      onSecondaryContainer: Color(0xFFE2E8F0),
      tertiary: Color(0xFF34D399),
      onTertiary: darkOledBackground,
      tertiaryContainer: Color(0xFF064E3B),
      onTertiaryContainer: Color(0xFFA7F3D0),
      error: Color(0xFFF87171),
      onError: darkOledBackground,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: Color(0xFF111827),
      onSurface: Color(0xFFF1F5F9),
      surfaceContainerLowest: darkOledBackground,
      surfaceContainerLow: Color(0xFF0E1422),
      surfaceContainer: Color(0xFF161F30),
      surfaceContainerHigh: Color(0xFF1E293B),
      surfaceContainerHighest: Color(0xFF283548),
      onSurfaceVariant: Color(0xFF94A3B8),
      outline: Color(0xFF475569),
      outlineVariant: Color(0xFF1E293B),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFF1F5F9),
      onInverseSurface: Color(0xFF0F172A),
      inversePrimary: primaryBlue,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      semantics: semantics,
      scaffoldBackground: darkOledBackground,
      buttonPrimary: primaryBlueDark,
      buttonForeground: Colors.white,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required LedgerSemanticColors semantics,
    required Color scaffoldBackground,
    required Color buttonPrimary,
    required Color buttonForeground,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        shape: Border(
          bottom: BorderSide(color: semantics.border, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: semantics.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: semantics.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: semantics.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantics.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: semantics.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: semantics.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonPrimary,
          foregroundColor: buttonForeground,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide(color: semantics.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonPrimary,
        foregroundColor: buttonForeground,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark
              ? const BorderSide(color: Color(0xFF3B82F6), width: 1)
              : BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantics.surfaceCard,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: semantics.border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: isDark ? const Color(0xFF0E1422) : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: semantics.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFF8FAFC),
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: const Color(0xFF60A5FA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: [semantics],
    );
  }
}

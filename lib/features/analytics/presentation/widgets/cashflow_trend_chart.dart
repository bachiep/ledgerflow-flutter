import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/utils/currency_formatter.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';

class CashflowTrendChart extends StatelessWidget {
  const CashflowTrendChart({
    super.key,
    required this.points,
    this.currency = 'VND',
  });

  final List<MonthlyCashflowPoint> points;
  final String currency;

  static const List<String> _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ledgerColors;

    final totalIncome = points.fold<int>(0, (sum, p) => sum + p.incomeMinor);
    final totalExpense = points.fold<int>(0, (sum, p) => sum + p.expenseMinor);
    final totalNet = totalIncome - totalExpense;

    return Card(
      key: const Key('cashflow_trend_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '6-Month Cashflow Trend',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _LegendDot(color: colors.income, label: 'In'),
                const SizedBox(width: 10),
                _LegendDot(color: colors.expense, label: 'Out'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 176,
              width: double.infinity,
              child: CustomPaint(
                key: const Key('cashflow_trend_painter'),
                painter: _CashflowTrendPainter(
                  points: points,
                  monthLabels: points
                      .map((p) => _monthAbbr[(p.month.month - 1).clamp(0, 11)])
                      .toList(growable: false),
                  currency: currency,
                  incomeColor: colors.income,
                  expenseColor: colors.expense,
                  gridColor: colors.border,
                  labelColor: theme.colorScheme.onSurfaceVariant,
                  activeLabelColor: theme.colorScheme.primary,
                  baseTextStyle: theme.textTheme.labelSmall,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TrendStatItem(
                      label: '6M Income',
                      value: CurrencyFormatter.formatCompactAxis(
                        totalIncome,
                        currency: currency,
                      ),
                      color: colors.income,
                    ),
                  ),
                  Expanded(
                    child: _TrendStatItem(
                      label: '6M Expense',
                      value: CurrencyFormatter.formatCompactAxis(
                        totalExpense,
                        currency: currency,
                      ),
                      color: colors.expense,
                    ),
                  ),
                  Expanded(
                    child: _TrendStatItem(
                      label: '6M Net',
                      value: CurrencyFormatter.formatCompactAxis(
                        totalNet,
                        currency: currency,
                      ),
                      color: totalNet >= 0 ? colors.income : colors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _TrendStatItem extends StatelessWidget {
  const _TrendStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ).tabular,
          ),
        ),
      ],
    );
  }
}

class _CashflowTrendPainter extends CustomPainter {
  _CashflowTrendPainter({
    required this.points,
    required this.monthLabels,
    required this.currency,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
    required this.labelColor,
    required this.activeLabelColor,
    required this.baseTextStyle,
  });

  final List<MonthlyCashflowPoint> points;
  final List<String> monthLabels;
  final String currency;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;
  final Color labelColor;
  final Color activeLabelColor;
  final TextStyle? baseTextStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    const leftAxisWidth = 44.0;
    const bottomAxisHeight = 24.0;
    const topPadding = 8.0;
    const rightPadding = 4.0;

    final plotLeft = leftAxisWidth;
    final plotRight = math.max(plotLeft + 1, size.width - rightPadding);
    final plotTop = topPadding;
    final plotBottom = math.max(plotTop + 1, size.height - bottomAxisHeight);
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    var maxMinor = 0;
    for (final p in points) {
      maxMinor = math.max(maxMinor, math.max(p.incomeMinor, p.expenseMinor));
    }
    final scaleMax = maxMinor > 0 ? maxMinor : 1;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Draw 3 horizontal gridlines (100%, 50%, 0%) + Y-axis compact labels.
    for (final ratio in [1.0, 0.5, 0.0]) {
      final y = plotBottom - (plotHeight * ratio);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);

      final axisVal = maxMinor == 0 ? 0 : (scaleMax * ratio).round();
      final text = CurrencyFormatter.formatCompactAxis(
        axisVal,
        currency: currency,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: (baseTextStyle ?? const TextStyle()).copyWith(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: leftAxisWidth - 6);
      tp.paint(
        canvas,
        Offset(leftAxisWidth - tp.width - 6, y - tp.height / 2),
      );
    }

    final slotWidth = plotWidth / points.length;
    final barWidth = (slotWidth * 0.28).clamp(8.0, 18.0);
    const barGap = 3.0;

    final incomePaint = Paint()..color = incomeColor;
    final expensePaint = Paint()..color = expenseColor;
    final activeHighlightPaint = Paint()
      ..color = activeLabelColor.withValues(alpha: 0.06);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final slotLeft = plotLeft + (i * slotWidth);
      final centerX = slotLeft + slotWidth / 2;
      final isLatest = i == points.length - 1;

      if (isLatest) {
        final highlightRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            slotLeft + 2,
            plotTop,
            slotLeft + slotWidth - 2,
            plotBottom,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(highlightRect, activeHighlightPaint);
      }

      double barHeightFor(int valueMinor) {
        if (valueMinor <= 0) {
          return 0;
        }
        return math.max(3.0, (valueMinor / scaleMax) * plotHeight);
      }

      final incHeight = barHeightFor(point.incomeMinor);
      final expHeight = barHeightFor(point.expenseMinor);

      if (incHeight > 0) {
        final incRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centerX - barGap / 2 - barWidth,
            plotBottom - incHeight,
            barWidth,
            incHeight,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(incRect, incomePaint);
      }

      if (expHeight > 0) {
        final expRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centerX + barGap / 2,
            plotBottom - expHeight,
            barWidth,
            expHeight,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(expRect, expensePaint);
      }

      final label = i < monthLabels.length ? monthLabels[i] : '';
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: (baseTextStyle ?? const TextStyle()).copyWith(
            color: isLatest ? activeLabelColor : labelColor,
            fontSize: 11,
            fontWeight: isLatest ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: slotWidth);
      labelPainter.paint(
        canvas,
        Offset(centerX - labelPainter.width / 2, plotBottom + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CashflowTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.currency != currency ||
        oldDelegate.incomeColor != incomeColor ||
        oldDelegate.expenseColor != expenseColor ||
        oldDelegate.gridColor != gridColor;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/widgets/state_widgets.dart';

void main() {
  testWidgets('EmptyStateWidget invokes CTA callback when tapped', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.receipt_long,
            title: 'No entries yet',
            subtitle: 'Record your first expense or income.',
            actionLabel: 'Add transaction',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('No entries yet'), findsOneWidget);
    await tester.tap(find.text('Add transaction'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorStateWidget invokes retry callback when tapped', (
    WidgetTester tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorStateWidget(
            message: 'Database could not be opened.',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Database could not be opened.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}

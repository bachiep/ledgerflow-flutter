import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';

void main() {
  setUp(() async {
    await configureDependencies(
      config: const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
      database: AppDatabase.forTesting(NativeDatabase.memory()),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('LedgerFlowApp boots with 3-tab shell and toggles theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LedgerFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('LedgerFlow'), findsOneWidget);
    expect(find.text('Ledger'), findsWidgets);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Wallets'), findsOneWidget);

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(
      find.text('Monthly cashflow and budget alerts will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Toggle theme'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 11, 18, 9, 0));
    await configureDependencies(
      config: const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
      clock: clock,
      database: db,
    );

    final seeder = sl<SampleDataSeeder>();
    await seeder.seedDefaultCategories();
    await db.upsertWalletAtomic(
      id: 'wallet-test',
      name: 'Test Wallet',
      currency: 'VND',
      initialBalanceMinor: 1000000,
      isShared: false,
      updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'outbox-wallet-test',
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('LedgerPage renders EmptyState and saves a new offline transaction', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LedgerFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('Add Transaction'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_tx_fab')));
    await tester.pumpAndSettle();

    expect(find.text('New Transaction'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('tx_amount_field')),
      '125000',
    );
    await tester.enterText(
      find.byKey(const Key('tx_note_field')),
      'Matcha latte',
    );
    await tester.tap(find.byKey(const Key('tx_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Matcha latte'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/sync/data/connectivity_plus_network_connectivity.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final localNoon = DateTime(2026, 11, 18, 12, 0).toUtc();
    clock = FixedClock(localNoon);

    final seeder = SampleDataSeeder(db, clock);
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
    await db.markOutboxProcessed(
      items: await db.getPendingOutboxItems(),
      processedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
    );

    await configureDependencies(
      config: const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
      clock: clock,
      database: db,
      connectivity: const AlwaysOnlineNetworkConnectivity(),
      initialSession: const SessionGuest(),
    );
  });

  tearDown(() async {
    await disposeDependencies();
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
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Matcha latte'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets(
    'LedgerPage groups transactions by Today, Yesterday, and formatted date with daily subtotals',
    (WidgetTester tester) async {
      final todayLocalNoon = DateTime(2026, 11, 18, 12, 0).toUtc();
      final yesterdayLocalNoon = DateTime(2026, 11, 17, 12, 0).toUtc();
      final olderLocalNoon = DateTime(2026, 11, 14, 12, 0).toUtc();

      await tester.runAsync(() async {
        await db.upsertTransactionAtomic(
          id: 'tx-today',
          walletId: 'wallet-test',
          categoryId: SampleDataSeeder.catCoffeeId,
          type: 'expense',
          amountMinor: 75000,
          note: 'Today coffee',
          occurredAtEpochMs: todayLocalNoon.millisecondsSinceEpoch,
          updatedAtEpochMs: todayLocalNoon.millisecondsSinceEpoch,
          outboxId: 'o-today',
        );
        await db.upsertTransactionAtomic(
          id: 'tx-yesterday',
          walletId: 'wallet-test',
          categoryId: SampleDataSeeder.catFoodId,
          type: 'expense',
          amountMinor: 150000,
          note: 'Yesterday lunch',
          occurredAtEpochMs: yesterdayLocalNoon.millisecondsSinceEpoch,
          updatedAtEpochMs: yesterdayLocalNoon.millisecondsSinceEpoch,
          outboxId: 'o-yesterday',
        );
        await db.upsertTransactionAtomic(
          id: 'tx-older',
          walletId: 'wallet-test',
          categoryId: SampleDataSeeder.catSalaryId,
          type: 'income',
          amountMinor: 500000,
          note: 'Older bonus',
          occurredAtEpochMs: olderLocalNoon.millisecondsSinceEpoch,
          updatedAtEpochMs: olderLocalNoon.millisecondsSinceEpoch,
          outboxId: 'o-older',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpWidget(const LedgerFlowApp());
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today coffee'), findsOneWidget);
      expect(find.text('Yesterday lunch'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Sat, Nov 14'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Sat, Nov 14'), findsOneWidget);
      expect(find.text('Older bonus'), findsOneWidget);
    },
  );

  testWidgets(
    'Tap-to-edit opens prefilled TransactionFormSheet and saves updated entry',
    (WidgetTester tester) async {
      final todayLocalNoon = DateTime(2026, 11, 18, 12, 0).toUtc();
      await tester.runAsync(() async {
        await db.upsertTransactionAtomic(
          id: 'tx-edit-flow',
          walletId: 'wallet-test',
          categoryId: SampleDataSeeder.catCoffeeId,
          type: 'expense',
          amountMinor: 75000,
          note: 'Morning drip',
          occurredAtEpochMs: todayLocalNoon.millisecondsSinceEpoch,
          updatedAtEpochMs: todayLocalNoon.millisecondsSinceEpoch,
          outboxId: 'o-edit-init',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpWidget(const LedgerFlowApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tx_card_tx-edit-flow')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.text('75000'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('tx_note_field')),
          matching: find.text('Morning drip'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('tx_amount_field')),
        '125000',
      );
      await tester.enterText(
        find.byKey(const Key('tx_note_field')),
        'Matcha and croissant',
      );
      await tester.tap(find.byKey(const Key('tx_submit_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matcha and croissant'), findsOneWidget);
      expect(find.text('Morning drip'), findsNothing);
    },
  );

  testWidgets(
    'Soft-deleting a transaction shows 5-second Undo SnackBar and UNDO restores it',
    (WidgetTester tester) async {
      final todayLocalNoon = DateTime(2026, 11, 18, 12, 0).toUtc();
      await tester.runAsync(() async {
        await db.upsertTransactionAtomic(
          id: 'tx-undo-ui',
          walletId: 'wallet-test',
          categoryId: SampleDataSeeder.catFoodId,
          type: 'expense',
          amountMinor: 90000,
          note: 'Banh mi snack',
          occurredAtEpochMs: todayLocalNoon.millisecondsSinceEpoch,
          updatedAtEpochMs: todayLocalNoon.millisecondsSinceEpoch,
          outboxId: 'o-undo-init',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpWidget(const LedgerFlowApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tx_menu_tx-undo-ui')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Banh mi snack'), findsNothing);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Banh mi snack'), findsOneWidget);
    },
  );

  testWidgets(
    'Ledger, Analytics, and Wallets render without overflow at 320px and 393px widths',
    (WidgetTester tester) async {
      await tester.runAsync(() async {
        await db.clearAllData();
        await SampleDataSeeder(db, clock).seedGuestSampleIfEmpty();
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (sl<TransactionsCubit>().state is TransactionsLoaded &&
              sl<AnalyticsCubit>().state is AnalyticsLoaded) {
            break;
          }
        }
      });

      for (final size in const [Size(320, 568), Size(393, 852)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(const LedgerFlowApp());
        await tester.runAsync(() async {
          for (var i = 0; i < 30; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            if (sl<TransactionsCubit>().state is TransactionsLoaded) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Analytics'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const Key('cashflow_trend_card')),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byKey(const Key('cashflow_trend_card')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Wallets'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Personal'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Personal'), findsOneWidget);
        expect(find.text('Inflow'), findsWidgets);
        expect(find.text('Outflow'), findsWidgets);
        expect(find.text('Net Delta'), findsWidgets);
        await tester.scrollUntilVisible(
          find.text('Shared'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Shared'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Ledger'));
        await tester.pumpAndSettle();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}

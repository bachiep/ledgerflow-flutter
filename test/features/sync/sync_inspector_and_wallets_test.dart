import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/sync/data/connectivity_plus_network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/data/simulated_remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/data/sync_repository_impl.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_repository.dart';
import 'package:ledgerflow_flutter/features/sync/presentation/bloc/sync_inspector_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/widgets/transaction_form_sheet.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncRepository extends Mock implements SyncRepository {}

void main() {
  group('SyncInspectorCubit', () {
    late _MockSyncRepository mockRepo;

    setUp(() {
      mockRepo = _MockSyncRepository();
    });

    blocTest<SyncInspectorCubit, SyncInspectorState>(
      'emits SyncInspectorEmpty when outbox is empty',
      setUp: () {
        when(() => mockRepo.watchOutboxItems())
            .thenAnswer((_) => Stream.value(const []));
      },
      build: () => SyncInspectorCubit(mockRepo),
      expect: () => [const SyncInspectorEmpty()],
    );

    blocTest<SyncInspectorCubit, SyncInspectorState>(
      'emits SyncInspectorLoaded and counts pending vs synced rows',
      setUp: () {
        when(() => mockRepo.watchOutboxItems()).thenAnswer(
          (_) => Stream.value([
            SyncOutboxItem(
              id: 'o1',
              entityType: 'transaction',
              entityId: 't1',
              operation: 'upsert',
              payloadJson: '{}',
              attempts: 0,
              lastError: null,
              createdAt: DateTime.utc(2026, 11, 18),
              processedAt: null,
            ),
            SyncOutboxItem(
              id: 'o2',
              entityType: 'transaction',
              entityId: 't2',
              operation: 'delete',
              payloadJson: '{}',
              attempts: 0,
              lastError: null,
              createdAt: DateTime.utc(2026, 11, 18),
              processedAt: DateTime.utc(2026, 11, 18, 1),
            ),
          ]),
        );
      },
      build: () => SyncInspectorCubit(mockRepo),
      expect: () => [
        isA<SyncInspectorLoaded>()
            .having((s) => s.pendingCount, 'pending', 1)
            .having((s) => s.syncedCount, 'synced', 1),
      ],
    );

    blocTest<SyncInspectorCubit, SyncInspectorState>(
      'emits SyncInspectorError on stream error and recovers on start()',
      setUp: () {
        var count = 0;
        when(() => mockRepo.watchOutboxItems()).thenAnswer((_) {
          count++;
          if (count == 1) {
            return Stream<List<SyncOutboxItem>>.error(Exception('DB locked'));
          }
          return Stream.value(const []);
        });
      },
      build: () => SyncInspectorCubit(mockRepo),
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.start();
      },
      expect: () => [
        isA<SyncInspectorError>(),
        const SyncInspectorLoading(),
        const SyncInspectorEmpty(),
      ],
    );
  });

  group('Offline -> Outbox Inspector -> Online Sync & Wallets Flow', () {
    setUp(() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final clock = FixedClock(DateTime.utc(2026, 11, 18, 10, 0));

      final seeder = SampleDataSeeder(db, clock);
      await seeder.seedDefaultCategories();
      await db.upsertWalletAtomic(
        id: 'wallet-personal',
        name: 'Personal Cash',
        currency: 'VND',
        initialBalanceMinor: 1000000,
        isShared: false,
        updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
        outboxId: 'o-init-wallet',
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
        simulatedDataSource: SimulatedRemoteSyncDataSource(
          clock: clock,
          simulatedLatency: Duration.zero,
        ),
        initialSession: const SessionGuest(),
      );
    });

    tearDown(() async {
      await disposeDependencies();
    });

    testWidgets(
      'Simulate Offline queues writes as PENDING and flushes to SYNCED when disabled',
      (WidgetTester tester) async {
        await tester.pumpWidget(const LedgerFlowApp());
        await tester.pumpAndSettle();

        // Open Sync Inspector and enable Simulate Offline
        await tester.tap(find.byKey(const Key('sync_status_button')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sync Outbox Inspector'), findsOneWidget);

        await tester.tap(find.byKey(const Key('simulate_offline_switch')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Offline simulation active'), findsOneWidget);

        // Create an offline transaction
        await tester.tap(find.byKey(const Key('add_tx_fab')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('tx_amount_field')),
          '25000',
        );
        await tester.enterText(
          find.byKey(const Key('tx_note_field')),
          'Bus fare',
        );
        await tester.tap(find.byKey(const Key('tx_submit_button')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bus fare'), findsOneWidget);
        expect(find.text('PENDING'), findsOneWidget);

        // Open Sync Inspector -> see queued item -> disable Simulate Offline -> auto-syncs to SYNCED
        await tester.tap(find.byKey(const Key('sync_status_button')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pumpAndSettle();
        expect(find.text('UPSERT TRANSACTION'), findsOneWidget);

        await tester.tap(find.byKey(const Key('simulate_offline_switch')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pumpAndSettle();

        expect(find.text('0 pending in outbox'), findsNothing);
        expect(find.textContaining('Synced 1 pushed'), findsOneWidget);

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('SYNCED'), findsOneWidget);
      },
    );

    testWidgets('WalletsPage creates a shared group wallet and filters ledger', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const LedgerFlowApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wallets'));
      await tester.pumpAndSettle();

      expect(find.text('Personal Cash'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_wallet_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wallet_name_field')),
        'Da Lat Trip Fund',
      );
      await tester.enterText(
        find.byKey(const Key('wallet_balance_field')),
        '2000000',
      );
      await tester.tap(find.byKey(const Key('wallet_shared_switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wallet_submit_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Da Lat Trip Fund'), findsOneWidget);
      expect(find.text('Shared'), findsOneWidget);
    });

    testWidgets(
      'WalletsPage Quick Transfer validates balance and executes atomic transfer between wallets',
      (WidgetTester tester) async {
        final db = sl<AppDatabase>();
        final clock = sl<AppClock>();
        await db.upsertWalletAtomic(
          id: 'wallet-savings',
          name: 'Savings Vault',
          currency: 'VND',
          initialBalanceMinor: 500000,
          isShared: false,
          updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
          outboxId: 'o-init-w2',
        );

        await tester.pumpWidget(const LedgerFlowApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Wallets'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Savings Vault'), findsOneWidget);
        expect(find.byKey(const Key('quick_transfer_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('quick_transfer_button')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wallet Transfer'), findsOneWidget);

        // Overdraft validation test
        await tester.enterText(
          find.byKey(const Key('transfer_amount_field')),
          '9999999999',
        );
        await tester.tap(find.byKey(const Key('transfer_submit_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Insufficient balance'), findsOneWidget);

        // Valid transfer
        await tester.enterText(
          find.byKey(const Key('transfer_amount_field')),
          '250000',
        );
        await tester.enterText(
          find.byKey(const Key('transfer_note_field')),
          'Fund rebalance',
        );
        await tester.tap(find.byKey(const Key('transfer_submit_button')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wallet Transfer'), findsNothing);
        expect(find.textContaining('Transferred'), findsOneWidget);
      },
    );

    testWidgets(
      'LedgerPage shows active wallet filter banner with 1-tap Clear / Show All button',
      (WidgetTester tester) async {
        await tester.pumpWidget(const LedgerFlowApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Wallets'));
        await tester.pumpAndSettle();

        // Tap on Personal Cash wallet card to filter
        await tester.tap(find.text('Personal Cash'));
        await tester.pumpAndSettle();

        // Verify active wallet filter banner on LedgerPage
        expect(
          find.byKey(const Key('active_wallet_filter_banner')),
          findsOneWidget,
        );
        expect(find.text('Showing: Personal Cash'), findsWidgets);
        expect(
          find.byKey(const Key('clear_wallet_filter_button')),
          findsOneWidget,
        );

        // 1-tap clear / Show All
        await tester.tap(find.byKey(const Key('clear_wallet_filter_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('active_wallet_filter_banner')),
          findsNothing,
        );
      },
    );
  });

  test('Soft-delete tombstone sync propagates deletion to a second device', () async {
    final clock = FixedClock(DateTime.utc(2026, 11, 18, 12, 0));
    final sharedRemote = SimulatedRemoteSyncDataSource(
      clock: clock,
      simulatedLatency: Duration.zero,
    );

    final dbA = AppDatabase.forTesting(NativeDatabase.memory());
    await SampleDataSeeder(dbA, clock).seedDefaultCategories();
    await dbA.upsertWalletAtomic(
      id: 'w-shared',
      name: 'Trip Pool',
      currency: 'VND',
      initialBalanceMinor: 1000000,
      isShared: true,
      updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'o-w',
    );
    await dbA.upsertTransactionAtomic(
      id: 'tx-tombstone',
      walletId: 'w-shared',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 120000,
      note: 'Mistaken entry',
      occurredAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'o-t1',
    );

    clock.advance(const Duration(minutes: 2));
    await dbA.softDeleteTransactionAtomic(
      transactionId: 'tx-tombstone',
      deletedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'o-t1-del',
    );

    final repoA = SyncRepositoryImpl(
      database: dbA,
      cloudDataSource: sharedRemote,
      simulatedDataSource: sharedRemote,
      connectivity: const AlwaysOnlineNetworkConnectivity(),
      clock: clock,
    );
    final pushResult = await repoA.synchronize(
      userId: 'guest-local',
      simulateOffline: false,
      isGuestMode: true,
    );
    expect(pushResult.isSuccess, isTrue);
    await dbA.close();

    final dbB = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(dbB.close);
    await SampleDataSeeder(dbB, clock).seedDefaultCategories();
    final repoB = SyncRepositoryImpl(
      database: dbB,
      cloudDataSource: sharedRemote,
      simulatedDataSource: sharedRemote,
      connectivity: const AlwaysOnlineNetworkConnectivity(),
      clock: clock,
    );
    await repoB.synchronize(
      userId: 'guest-local',
      simulateOffline: false,
      isGuestMode: true,
    );

    final activeOnDeviceB = await dbB.watchActiveTransactions().first;
    expect(activeOnDeviceB, isEmpty);
  });

  testWidgets('TransactionFormSheet renders without RenderFlex overflow on 320px width with keyboard insets', (
    WidgetTester tester,
  ) async {
    final mockTxRepo = _FakeTransactionRepoForOverflow();
    final wallets = [
      Wallet(
        id: 'w1',
        name: 'Very Long Personal & Group Wallet Name For Narrow Screen',
        currency: 'VND',
        initialBalanceMinor: 1000000,
        currentBalanceMinor: 1000000,
        isShared: true,
        updatedAt: DateTime.utc(2026, 11, 18),
        syncStatus: SyncStatus.synced,
      ),
    ];
    const categories = [
      CategoryItem(
        id: 'c1',
        name: 'Food & Dining Category',
        type: TransactionType.expense,
        iconName: 'restaurant',
        colorHex: 0xFFEA580C,
        monthlyBudgetMinor: 1000000,
      ),
    ];

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          viewInsets: EdgeInsets.only(bottom: 240),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransactionFormSheet(
              transactionRepository: mockTxRepo,
              wallets: wallets,
              categories: categories,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('tx_submit_button')), findsOneWidget);
  });
}

class _FakeTransactionRepoForOverflow extends Mock
    implements TransactionRepository {}

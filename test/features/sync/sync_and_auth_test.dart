import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/app.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/di/service_locator.dart';
import 'package:ledgerflow_flutter/core/error/failure.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/auth/domain/auth_repository.dart';
import 'package:ledgerflow_flutter/features/sync/data/connectivity_plus_network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/data/simulated_remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/data/sync_repository_impl.dart';
import 'package:ledgerflow_flutter/features/sync/domain/network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/domain/remote_sync_data_source.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_repository.dart';
import 'package:ledgerflow_flutter/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncRepository extends Mock implements SyncRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockRemoteSyncDataSource extends Mock implements RemoteSyncDataSource {}

class _FakeConnectivity implements NetworkConnectivity {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onIsOnlineChanged => _controller.stream;

  void emitOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      SyncOutboxItem(
        id: 'fallback',
        entityType: 'transaction',
        entityId: 'tx',
        operation: 'upsert',
        payloadJson: '{}',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.utc(2026),
        processedAt: null,
      ),
    );
  });

  group('SyncBloc', () {
    late _MockSyncRepository syncRepo;
    late _MockAuthRepository authRepo;
    late _FakeConnectivity connectivity;

    setUp(() {
      syncRepo = _MockSyncRepository();
      authRepo = _MockAuthRepository();
      connectivity = _FakeConnectivity();

      when(() => authRepo.currentSession).thenReturn(const SessionGuest());
      when(() => syncRepo.watchPendingOutboxCount())
          .thenAnswer((_) => Stream.value(2));
    });

    tearDown(() async {
      await connectivity.dispose();
    });

    blocTest<SyncBloc, SyncState>(
      'drops concurrent SyncRequested events via droppable()',
      setUp: () {
        when(
          () => syncRepo.synchronize(
            userId: any(named: 'userId'),
            simulateOffline: any(named: 'simulateOffline'),
            isGuestMode: any(named: 'isGuestMode'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return Success(
            SyncRunSummary(
              pushedCount: 2,
              pulledCount: 0,
              syncedAt: DateTime.utc(2026, 11, 18, 10, 0),
            ),
          );
        });
      },
      build: () => SyncBloc(
        syncRepository: syncRepo,
        authRepository: authRepo,
        connectivity: connectivity,
      )..add(const SyncStarted()),
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const SyncRequested())
          ..add(const SyncRequested())
          ..add(const SyncRequested());
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) {
        verify(
          () => syncRepo.synchronize(
            userId: 'guest-local',
            simulateOffline: false,
            isGuestMode: true,
          ),
        ).called(1);
      },
      expect: () => [
        const SyncIdle(pendingCount: 2, simulateOffline: false),
        const SyncInProgress(pendingCount: 2, simulateOffline: false),
        SyncSuccess(
          summary: SyncRunSummary(
            pushedCount: 2,
            pulledCount: 0,
            syncedAt: DateTime.utc(2026, 11, 18, 10, 0),
          ),
          pendingCount: 0,
          simulateOffline: false,
          lastSyncedAt: DateTime.utc(2026, 11, 18, 10, 0),
        ),
      ],
    );

    blocTest<SyncBloc, SyncState>(
      'emits SyncFailureState and preserves pendingCount when sync fails',
      setUp: () {
        when(
          () => syncRepo.synchronize(
            userId: any(named: 'userId'),
            simulateOffline: any(named: 'simulateOffline'),
            isGuestMode: any(named: 'isGuestMode'),
          ),
        ).thenAnswer(
          (_) async => const Err(SyncFailure('Timeout reaching Supabase')),
        );
      },
      build: () => SyncBloc(
        syncRepository: syncRepo,
        authRepository: authRepo,
        connectivity: connectivity,
      )..add(const SyncStarted()),
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SyncRequested());
      },
      expect: () => [
        const SyncIdle(pendingCount: 2, simulateOffline: false),
        const SyncInProgress(pendingCount: 2, simulateOffline: false),
        const SyncFailureState(
          message: 'Timeout reaching Supabase',
          pendingCount: 2,
          simulateOffline: false,
        ),
      ],
    );

    blocTest<SyncBloc, SyncState>(
      'automatically syncs when SimulateOffline is toggled off with pending items',
      setUp: () {
        when(
          () => syncRepo.synchronize(
            userId: any(named: 'userId'),
            simulateOffline: false,
            isGuestMode: true,
          ),
        ).thenAnswer(
          (_) async => Success(
            SyncRunSummary(
              pushedCount: 2,
              pulledCount: 0,
              syncedAt: DateTime.utc(2026, 11, 18, 11, 0),
            ),
          ),
        );
      },
      build: () => SyncBloc(
        syncRepository: syncRepo,
        authRepository: authRepo,
        connectivity: connectivity,
      )..add(const SyncStarted()),
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SimulateOfflineToggled(true));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SimulateOfflineToggled(false));
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const SyncIdle(pendingCount: 2, simulateOffline: false),
        const SyncIdle(pendingCount: 2, simulateOffline: true),
        const SyncIdle(pendingCount: 2, simulateOffline: false),
        const SyncInProgress(pendingCount: 2, simulateOffline: false),
        SyncSuccess(
          summary: SyncRunSummary(
            pushedCount: 2,
            pulledCount: 0,
            syncedAt: DateTime.utc(2026, 11, 18, 11, 0),
          ),
          pendingCount: 0,
          simulateOffline: false,
          lastSyncedAt: DateTime.utc(2026, 11, 18, 11, 0),
        ),
      ],
    );
  });

  group('SyncRepositoryImpl + Drift LWW Integration', () {
    late AppDatabase db;
    late FixedClock clock;
    late SimulatedRemoteSyncDataSource simulated;
    late _MockRemoteSyncDataSource failingCloud;
    late _FakeConnectivity connectivity;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      clock = FixedClock(DateTime.utc(2026, 11, 18, 12, 0));
      simulated = SimulatedRemoteSyncDataSource(
        clock: clock,
        simulatedLatency: Duration.zero,
      );
      failingCloud = _MockRemoteSyncDataSource();
      connectivity = _FakeConnectivity();

      final seeder = SampleDataSeeder(db, clock);
      await seeder.seedDefaultCategories();
      await db.upsertWalletAtomic(
        id: 'w-sync',
        name: 'Sync Wallet',
        currency: 'VND',
        initialBalanceMinor: 2000000,
        isShared: false,
        updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
        outboxId: 'o-w-sync',
      );
    });

    tearDown(() async {
      await connectivity.dispose();
      await db.close();
    });

    test('retains outbox item on push error and succeeds on retry', () async {
      when(
        () => failingCloud.ensureCategories(
          any(),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      var attempt = 0;
      when(
        () => failingCloud.pushOutboxItem(any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {
        attempt++;
        if (attempt == 1) {
          throw Exception('503 Cloud Down');
        }
      });
      when(
        () => failingCloud.pullChangesSince(any(), userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => RemoteDeltaBatch(
          wallets: const [],
          transactions: const [],
          serverEpochMs: clock.nowUtc().millisecondsSinceEpoch,
        ),
      );

      final repo = SyncRepositoryImpl(
        database: db,
        cloudDataSource: failingCloud,
        simulatedDataSource: simulated,
        connectivity: connectivity,
        clock: clock,
      );

      final firstRun = await repo.synchronize(
        userId: 'user-1',
        simulateOffline: false,
        isGuestMode: false,
      );
      expect(firstRun.isFailure, isTrue);

      final retained = await db.getPendingOutboxItems();
      expect(retained, hasLength(1));
      expect(retained.single.attempts, 1);
      expect(retained.single.lastError, contains('503 Cloud Down'));

      final secondRun = await repo.synchronize(
        userId: 'user-1',
        simulateOffline: false,
        isGuestMode: false,
      );
      expect(secondRun.isSuccess, isTrue);
      expect(await db.getPendingOutboxItems(), isEmpty);
    });

    test('applies Last-Write-Wins deterministically during delta pull', () async {
      final repo = SyncRepositoryImpl(
        database: db,
        cloudDataSource: simulated,
        simulatedDataSource: simulated,
        connectivity: connectivity,
        clock: clock,
      );

      // Push initial wallet first
      await repo.synchronize(
        userId: 'guest-local',
        simulateOffline: false,
        isGuestMode: true,
      );

      // Local newer edit at t = 12:10
      clock.advance(const Duration(minutes: 10));
      final localTimeMs = clock.nowUtc().millisecondsSinceEpoch;
      await db.upsertTransactionAtomic(
        id: 'tx-lww',
        walletId: 'w-sync',
        categoryId: SampleDataSeeder.catFoodId,
        type: 'expense',
        amountMinor: 300000,
        note: 'Local newer note',
        occurredAtEpochMs: localTimeMs,
        updatedAtEpochMs: localTimeMs,
        outboxId: 'o-tx-lww',
      );

      // Remote older stale version at t = 12:05 (must NOT overwrite local)
      simulated.seedRemoteTransaction({
        'id': 'tx-lww',
        'wallet_id': 'w-sync',
        'category_id': SampleDataSeeder.catFoodId,
        'type': 'expense',
        'amount_minor': 999000,
        'note': 'Stale remote note',
        'occurred_at_epoch_ms': localTimeMs - 300000,
        'updated_at_epoch_ms': localTimeMs - 300000,
        'deleted_at_epoch_ms': null,
      });

      // Remote brand new record at t = 12:15 (must be applied locally)
      simulated.seedRemoteTransaction({
        'id': 'tx-remote-new',
        'wallet_id': 'w-sync',
        'category_id': SampleDataSeeder.catCoffeeId,
        'type': 'expense',
        'amount_minor': 65000,
        'note': 'Added from second device',
        'occurred_at_epoch_ms': localTimeMs + 300000,
        'updated_at_epoch_ms': localTimeMs + 300000,
        'deleted_at_epoch_ms': null,
      });

      // Clear pending outbox first so pull runs without pushing local edit over remote test
      await db.markOutboxProcessed(
        items: await db.getPendingOutboxItems(),
        processedAtEpochMs: localTimeMs,
      );

      final result = await repo.synchronize(
        userId: 'guest-local',
        simulateOffline: false,
        isGuestMode: true,
      );
      expect(result.isSuccess, isTrue);

      final txs = await db.watchActiveTransactions().first;
      final localTx = txs.firstWhere((r) => r.transaction.id == 'tx-lww');
      final remoteTx =
          txs.firstWhere((r) => r.transaction.id == 'tx-remote-new');

      expect(localTx.transaction.note, 'Local newer note');
      expect(localTx.transaction.amountMinor, 300000);
      expect(remoteTx.transaction.note, 'Added from second device');
    });
  });

  group('WelcomePage', () {
    setUp(() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await configureDependencies(
        config: const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
        database: db,
        connectivity: const AlwaysOnlineNetworkConnectivity(),
        simulatedDataSource: SimulatedRemoteSyncDataSource(
          clock: const SystemClock(),
          simulatedLatency: Duration.zero,
        ),
      );
    });

    tearDown(() async {
      await disposeDependencies();
    });

    testWidgets(
      '1-tap Guest Mode seeds 30-day data and opens LedgerPage',
      (WidgetTester tester) async {
        await tester.pumpWidget(const LedgerFlowApp());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('guest_mode_button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('guest_mode_button')));
        await tester.pump();
        await tester.runAsync(() async {
          for (var i = 0; i < 50; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            if (sl<TransactionsCubit>().state is TransactionsLoaded) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();

        expect(find.text('Total Balance'), findsOneWidget);
        expect(find.text('Morning espresso & banh mi'), findsOneWidget);
        expect(find.byKey(const Key('add_tx_fab')), findsOneWidget);
      },
    );
  });
}

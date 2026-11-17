import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SampleDataSeeder seeder;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 11, 18, 9, 0));
    seeder = SampleDataSeeder(db, clock);
    await seeder.seedDefaultCategories();
    await db.upsertWalletAtomic(
      id: 'wallet-1',
      name: 'Main Wallet',
      currency: 'VND',
      initialBalanceMinor: 1000000,
      isShared: false,
      updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'outbox-w1',
    );
    final pendingAfterWallet = await db.getPendingOutboxItems();
    await db.markOutboxProcessed(
      items: pendingAfterWallet,
      processedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertTransactionAtomic writes transaction and outbox atomically', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertTransactionAtomic(
      id: 'tx-1',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 150000,
      note: 'Lunch pho',
      occurredAtEpochMs: nowMs,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-1',
    );

    final active = await db.watchActiveTransactions().first;
    expect(active, hasLength(1));
    expect(active.first.transaction.id, 'tx-1');
    expect(active.first.transaction.syncStatus, 'pending');
    expect(active.first.category.name, 'Food & Dining');

    final outbox = await db.getPendingOutboxItems();
    expect(outbox, hasLength(1));
    expect(outbox.first.entityId, 'tx-1');
    expect(outbox.first.operation, 'upsert');
    expect(outbox.first.processedAtEpochMs, isNull);
  });

  test('upsertTransactionAtomic rolls back when foreign key fails', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await expectLater(
      () => db.upsertTransactionAtomic(
        id: 'tx-invalid',
        walletId: 'missing-wallet',
        categoryId: SampleDataSeeder.catFoodId,
        type: 'expense',
        amountMinor: 50000,
        note: 'Should fail',
        occurredAtEpochMs: nowMs,
        updatedAtEpochMs: nowMs,
        outboxId: 'outbox-invalid',
      ),
      throwsA(isA<Object>()),
    );

    final outbox = await db.getPendingOutboxItems();
    expect(outbox, isEmpty);
  });

  test('softDeleteTransactionAtomic updates wallet balance and enqueues tombstone', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertTransactionAtomic(
      id: 'tx-2',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 250000,
      note: 'Dinner',
      occurredAtEpochMs: nowMs,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-create',
    );

    var wallets = await db.watchWalletsWithBalance().first;
    expect(wallets.single.currentBalanceMinor, 750000);

    clock.advance(const Duration(minutes: 5));
    final deleted = await db.softDeleteTransactionAtomic(
      transactionId: 'tx-2',
      deletedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'outbox-delete',
    );
    expect(deleted, isTrue);

    final active = await db.watchActiveTransactions().first;
    expect(active, isEmpty);

    wallets = await db.watchWalletsWithBalance().first;
    expect(wallets.single.currentBalanceMinor, 1000000);

    final outbox = await db.getPendingOutboxItems();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, 'delete');
  });

  test('markOutboxProcessed clears pending count and marks transaction synced', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertTransactionAtomic(
      id: 'tx-3',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catSalaryId,
      type: 'income',
      amountMinor: 500000,
      note: 'Bonus',
      occurredAtEpochMs: nowMs,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-3',
    );

    expect(await db.watchPendingOutboxCount().first, 1);

    final pending = await db.getPendingOutboxItems();
    await db.markOutboxProcessed(
      items: pending,
      processedAtEpochMs: nowMs + 1000,
    );

    expect(await db.watchPendingOutboxCount().first, 0);
    final active = await db.watchActiveTransactions().first;
    expect(active.single.transaction.syncStatus, 'synced');
  });

  test('upsertTransactionAtomic updates existing transaction and recalculates balance', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertTransactionAtomic(
      id: 'tx-edit',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 100000,
      note: 'Original lunch',
      occurredAtEpochMs: nowMs,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-edit-1',
    );

    await db.upsertTransactionAtomic(
      id: 'tx-edit',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 180000,
      note: 'Updated team lunch',
      occurredAtEpochMs: nowMs,
      updatedAtEpochMs: nowMs + 500,
      outboxId: 'outbox-edit-2',
    );

    final wallets = await db.watchWalletsWithBalance().first;
    expect(wallets.single.currentBalanceMinor, 820000);

    final filtered = await db
        .watchActiveTransactions(searchQuery: 'TEAM')
        .first;
    expect(filtered, hasLength(1));
    expect(filtered.single.transaction.amountMinor, 180000);
    expect(await db.watchPendingOutboxCount().first, 2);
  });

  test('recordOutboxFailure increments attempts and marks entity failed', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertTransactionAtomic(
      id: 'tx-fail',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 75000,
      note: 'Offline coffee',
      occurredAtEpochMs: nowMs,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-fail-1',
    );

    final pending = await db.getPendingOutboxItems();
    await db.recordOutboxFailure(
      item: pending.single,
      errorMessage: '503 Service Unavailable',
    );

    final stillPending = await db.getPendingOutboxItems();
    expect(stillPending.single.attempts, 1);
    expect(stillPending.single.lastError, '503 Service Unavailable');

    final active = await db.watchActiveTransactions().first;
    expect(active.single.transaction.syncStatus, 'failed');
  });

  test('SampleDataSeeder populates 30-day sample dataset idempotently', () async {
    await db.clearAllData();

    final freshSeeder = SampleDataSeeder(db, clock);
    await freshSeeder.seedGuestSampleIfEmpty();
    await freshSeeder.seedGuestSampleIfEmpty();

    final wallets = await db.watchWalletsWithBalance().first;
    final txs = await db.watchActiveTransactions().first;
    final pendingCount = await db.watchPendingOutboxCount().first;

    expect(wallets, hasLength(2));
    expect(txs, hasLength(16));
    expect(pendingCount, 0);
  });
}

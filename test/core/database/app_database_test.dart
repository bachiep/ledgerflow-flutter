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

  test('restoreTransactionAtomic restores soft-deleted row, balance, and enqueues upsert', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertTransactionAtomic(
      id: 'tx-undo',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 200000,
      note: 'Undoable dinner',
      occurredAtEpochMs: nowMs,
      updatedAtEpochMs: nowMs,
      outboxId: 'o-create',
    );
    clock.advance(const Duration(seconds: 10));
    await db.softDeleteTransactionAtomic(
      transactionId: 'tx-undo',
      deletedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'o-del',
    );

    expect(await db.watchActiveTransactions().first, isEmpty);
    expect(
      (await db.watchWalletsWithBalance().first).single.currentBalanceMinor,
      1000000,
    );

    clock.advance(const Duration(seconds: 3));
    final restored = await db.restoreTransactionAtomic(
      transactionId: 'tx-undo',
      updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
      outboxId: 'o-restore',
    );
    expect(restored, isTrue);

    final active = await db.watchActiveTransactions().first;
    expect(active, hasLength(1));
    expect(active.single.transaction.note, 'Undoable dinner');
    expect(
      (await db.watchWalletsWithBalance().first).single.currentBalanceMinor,
      800000,
    );

    final outbox = await db.getPendingOutboxItems();
    expect(outbox.last.operation, 'upsert');
    expect(outbox.last.payloadJson, contains('"deleted_at_epoch_ms":null'));
  });

  test('watchWalletsWithBalance computes current-month inflow, outflow, and tx count', () async {
    final novStart = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
    final decStart = DateTime.utc(2026, 12, 1).millisecondsSinceEpoch;
    final octDate = DateTime.utc(2026, 10, 20, 12).millisecondsSinceEpoch;
    final novDate = DateTime.utc(2026, 11, 10, 12).millisecondsSinceEpoch;

    await db.upsertTransactionAtomic(
      id: 'tx-oct-old',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catSalaryId,
      type: 'income',
      amountMinor: 500000,
      note: 'Oct stipend',
      occurredAtEpochMs: octDate,
      updatedAtEpochMs: octDate,
      outboxId: 'o-oct',
    );
    await db.upsertTransactionAtomic(
      id: 'tx-nov-in',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catSalaryId,
      type: 'income',
      amountMinor: 1200000,
      note: 'Nov stipend',
      occurredAtEpochMs: novDate,
      updatedAtEpochMs: novDate,
      outboxId: 'o-nov-in',
    );
    await db.upsertTransactionAtomic(
      id: 'tx-nov-out',
      walletId: 'wallet-1',
      categoryId: SampleDataSeeder.catFoodId,
      type: 'expense',
      amountMinor: 350000,
      note: 'Nov lunch',
      occurredAtEpochMs: novDate,
      updatedAtEpochMs: novDate,
      outboxId: 'o-nov-out',
    );

    final rows = await db
        .watchWalletsWithBalance(
          monthFromEpochMs: novStart,
          monthToEpochMs: decStart,
        )
        .first;
    final w = rows.single;
    expect(w.currentBalanceMinor, 1000000 + 500000 + 1200000 - 350000);
    expect(w.monthlyInflowMinor, 1200000);
    expect(w.monthlyOutflowMinor, 350000);
    expect(w.monthlyTxCount, 2);
  });

  test('updateCategoryBudget persists updated monthly cap in SQLite', () async {
    final ok = await db.updateCategoryBudget(
      categoryId: SampleDataSeeder.catCoffeeId,
      monthlyBudgetMinor: 1500000,
      updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
    );
    expect(ok, isTrue);

    final cats = await db.watchCategories().first;
    final coffee = cats.firstWhere((c) => c.id == SampleDataSeeder.catCoffeeId);
    expect(coffee.monthlyBudgetMinor, 1500000);
  });

  test('transferAtomic debits source wallet, credits destination wallet, and enqueues sync outbox mutations', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertWalletAtomic(
      id: 'wallet-dest',
      name: 'Savings Vault',
      currency: 'VND',
      initialBalanceMinor: 500000,
      isShared: false,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-w-dest',
    );
    final pendingInit = await db.getPendingOutboxItems();
    await db.markOutboxProcessed(items: pendingInit, processedAtEpochMs: nowMs);

    // Initial balances
    expect(await db.getWalletBalance('wallet-1'), 1000000);
    expect(await db.getWalletBalance('wallet-dest'), 500000);

    // Transfer 300,000 VND
    await db.transferAtomic(
      sourceWalletId: 'wallet-1',
      destinationWalletId: 'wallet-dest',
      amountMinor: 300000,
      note: 'Emergency savings',
      occurredAtEpochMs: nowMs,
      sourceTxId: 'tx-xfer-src',
      destinationTxId: 'tx-xfer-dst',
      sourceOutboxId: 'outbox-xfer-src',
      destinationOutboxId: 'outbox-xfer-dst',
    );

    // Balances reflect transfer
    expect(await db.getWalletBalance('wallet-1'), 700000);
    expect(await db.getWalletBalance('wallet-dest'), 800000);

    // Transactions created
    final txs = await db.watchActiveTransactions().first;
    expect(txs, hasLength(2));
    final srcTx = txs.firstWhere((t) => t.transaction.id == 'tx-xfer-src');
    final dstTx = txs.firstWhere((t) => t.transaction.id == 'tx-xfer-dst');

    expect(srcTx.transaction.type, 'expense');
    expect(srcTx.transaction.amountMinor, 300000);
    expect(srcTx.transaction.note, contains('Transfer to Savings Vault'));
    expect(srcTx.transaction.syncStatus, 'pending');

    expect(dstTx.transaction.type, 'income');
    expect(dstTx.transaction.amountMinor, 300000);
    expect(dstTx.transaction.note, contains('Transfer from Main Wallet'));
    expect(dstTx.transaction.syncStatus, 'pending');

    // Outbox entries enqueued
    final outbox = await db.getPendingOutboxItems();
    expect(outbox, hasLength(2));
    expect(
      outbox.map((o) => o.entityId),
      containsAll(['tx-xfer-src', 'tx-xfer-dst']),
    );
  });

  test('transferAtomic throws and does not debit when source wallet has insufficient balance', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertWalletAtomic(
      id: 'wallet-target',
      name: 'Vacation Pool',
      currency: 'VND',
      initialBalanceMinor: 200000,
      isShared: true,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-w-target',
    );
    final pendingInit = await db.getPendingOutboxItems();
    await db.markOutboxProcessed(items: pendingInit, processedAtEpochMs: nowMs);

    expect(await db.getWalletBalance('wallet-1'), 1000000);

    // Attempt to transfer 2,500,000 VND (> 1,000,000)
    await expectLater(
      () => db.transferAtomic(
        sourceWalletId: 'wallet-1',
        destinationWalletId: 'wallet-target',
        amountMinor: 2500000,
        note: 'Overdraft attempt',
        occurredAtEpochMs: nowMs,
        sourceTxId: 'tx-xfer-fail-src',
        destinationTxId: 'tx-xfer-fail-dst',
        sourceOutboxId: 'o-fail-src',
        destinationOutboxId: 'o-fail-dst',
      ),
      throwsA(isA<StateError>()),
    );

    // Balances and outbox untouched
    expect(await db.getWalletBalance('wallet-1'), 1000000);
    expect(await db.getWalletBalance('wallet-target'), 200000);
    expect(await db.getPendingOutboxItems(), isEmpty);
  });

  test('transferAtomic rolls back atomically when error occurs during transaction', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    expect(await db.getWalletBalance('wallet-1'), 1000000);

    // Destination wallet does not exist -> fails within transaction
    await expectLater(
      () => db.transferAtomic(
        sourceWalletId: 'wallet-1',
        destinationWalletId: 'non-existent-wallet-id',
        amountMinor: 100000,
        note: 'Rollback test',
        occurredAtEpochMs: nowMs,
        sourceTxId: 'tx-rollback-src',
        destinationTxId: 'tx-rollback-dst',
        sourceOutboxId: 'o-rb-src',
        destinationOutboxId: 'o-rb-dst',
      ),
      throwsA(isA<StateError>()),
    );

    // Full atomic rollback verification
    expect(await db.getWalletBalance('wallet-1'), 1000000);
    expect(await db.watchActiveTransactions().first, isEmpty);
    expect(await db.getPendingOutboxItems(), isEmpty);
  });

  test('transferAtomic mutations are processed and marked synced via markOutboxProcessed', () async {
    final nowMs = clock.nowUtc().millisecondsSinceEpoch;
    await db.upsertWalletAtomic(
      id: 'wallet-b',
      name: 'Secondary Wallet',
      currency: 'VND',
      initialBalanceMinor: 400000,
      isShared: false,
      updatedAtEpochMs: nowMs,
      outboxId: 'outbox-wb',
    );
    final pendingInit = await db.getPendingOutboxItems();
    await db.markOutboxProcessed(items: pendingInit, processedAtEpochMs: nowMs);

    await db.transferAtomic(
      sourceWalletId: 'wallet-1',
      destinationWalletId: 'wallet-b',
      amountMinor: 200000,
      note: 'Rebalance test',
      occurredAtEpochMs: nowMs,
      sourceTxId: 'tx-sync-src',
      destinationTxId: 'tx-sync-dst',
      sourceOutboxId: 'o-sync-src',
      destinationOutboxId: 'o-sync-dst',
    );

    expect(await db.watchPendingOutboxCount().first, 2);

    final pending = await db.getPendingOutboxItems();
    await db.markOutboxProcessed(items: pending, processedAtEpochMs: nowMs + 1000);

    expect(await db.watchPendingOutboxCount().first, 0);

    final txs = await db.watchActiveTransactions().first;
    expect(txs.every((t) => t.transaction.syncStatus == 'synced'), isTrue);
  });
}

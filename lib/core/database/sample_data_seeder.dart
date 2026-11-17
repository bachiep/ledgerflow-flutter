import 'package:drift/drift.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';

/// Seeds realistic 30-day Vietnamese personal and shared wallet data when empty.
final class SampleDataSeeder {
  SampleDataSeeder(this._db, this._clock);

  final AppDatabase _db;
  final AppClock _clock;

  static const String personalWalletId = '11111111-1111-4111-8111-111111111101';
  static const String sharedWalletId = '11111111-1111-4111-8111-111111111102';

  static const String catFoodId = '22222222-2222-4222-8222-222222222201';
  static const String catTransportId = '22222222-2222-4222-8222-222222222202';
  static const String catGroceriesId = '22222222-2222-4222-8222-222222222203';
  static const String catHousingId = '22222222-2222-4222-8222-222222222204';
  static const String catCoffeeId = '22222222-2222-4222-8222-222222222205';
  static const String catEntertainmentId =
      '22222222-2222-4222-8222-222222222206';
  static const String catSalaryId = '22222222-2222-4222-8222-222222222207';
  static const String catFreelanceId = '22222222-2222-4222-8222-222222222208';

  Future<void> seedDefaultCategories() async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.categories, _defaultCategories());
    });
  }

  List<CategoriesCompanion> _defaultCategories() {
    final nowMs = _clock.nowUtc().millisecondsSinceEpoch;
    return [
      CategoriesCompanion.insert(
        id: catFoodId,
        name: 'Food & Dining',
        type: 'expense',
        iconName: 'restaurant',
        colorHex: 0xFFEA580C,
        monthlyBudgetMinor: const Value(3500000),
        updatedAtEpochMs: nowMs,
      ),
      CategoriesCompanion.insert(
        id: catTransportId,
        name: 'Transport & Fuel',
        type: 'expense',
        iconName: 'directions_car',
        colorHex: 0xFF2563EB,
        monthlyBudgetMinor: const Value(1200000),
        updatedAtEpochMs: nowMs,
      ),
      CategoriesCompanion.insert(
        id: catGroceriesId,
        name: 'Groceries',
        type: 'expense',
        iconName: 'shopping_cart',
        colorHex: 0xFF16A34A,
        monthlyBudgetMinor: const Value(2500000),
        updatedAtEpochMs: nowMs,
      ),
      CategoriesCompanion.insert(
        id: catHousingId,
        name: 'Housing & Bills',
        type: 'expense',
        iconName: 'home',
        colorHex: 0xFF7C3AED,
        monthlyBudgetMinor: const Value(5000000),
        updatedAtEpochMs: nowMs,
      ),
      CategoriesCompanion.insert(
        id: catCoffeeId,
        name: 'Coffee & Snacks',
        type: 'expense',
        iconName: 'local_cafe',
        colorHex: 0xFFD97706,
        monthlyBudgetMinor: const Value(800000),
        updatedAtEpochMs: nowMs,
      ),
      CategoriesCompanion.insert(
        id: catEntertainmentId,
        name: 'Entertainment',
        type: 'expense',
        iconName: 'movie',
        colorHex: 0xFFDB2777,
        monthlyBudgetMinor: const Value(1000000),
        updatedAtEpochMs: nowMs,
      ),
      CategoriesCompanion.insert(
        id: catSalaryId,
        name: 'Salary & Allowance',
        type: 'income',
        iconName: 'payments',
        colorHex: 0xFF0F766E,
        monthlyBudgetMinor: const Value(0),
        updatedAtEpochMs: nowMs,
      ),
      CategoriesCompanion.insert(
        id: catFreelanceId,
        name: 'Freelance & Shared',
        type: 'income',
        iconName: 'work',
        colorHex: 0xFF0284C7,
        monthlyBudgetMinor: const Value(0),
        updatedAtEpochMs: nowMs,
      ),
    ];
  }

  /// Seeds 30-day sample wallets and transactions if no transactions exist yet.
  Future<void> seedGuestSampleIfEmpty() {
    return _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.categories, _defaultCategories());
      });

      final existingWallets = await _db.select(_db.wallets).get();
      if (existingWallets.isNotEmpty) {
        return;
      }

    final now = _clock.nowUtc();
    final nowMs = now.millisecondsSinceEpoch;
    DateTime daysAgo(int days, {int hour = 12}) {
      final target = now.subtract(Duration(days: days));
      return DateTime.utc(target.year, target.month, target.day, hour, 0);
    }

    final sampleWallets = [
      WalletsCompanion.insert(
        id: personalWalletId,
        name: 'Personal Cash & Bank',
        currency: const Value('VND'),
        initialBalanceMinor: const Value(6500000),
        isShared: const Value(false),
        updatedAtEpochMs: nowMs,
        syncStatus: const Value('synced'),
      ),
      WalletsCompanion.insert(
        id: sharedWalletId,
        name: 'Apartment Group Fund',
        currency: const Value('VND'),
        initialBalanceMinor: const Value(3000000),
        isShared: const Value(true),
        updatedAtEpochMs: nowMs,
        syncStatus: const Value('synced'),
      ),
    ];

    final samples = <({
      String id,
      String walletId,
      String categoryId,
      String type,
      int amount,
      String note,
      DateTime at,
    })>[
      (
        id: '33333333-3333-4333-8333-333333333301',
        walletId: personalWalletId,
        categoryId: catSalaryId,
        type: 'income',
        amount: 14500000,
        note: 'Monthly internship stipend & allowance',
        at: daysAgo(26, hour: 9),
      ),
      (
        id: '33333333-3333-4333-8333-333333333302',
        walletId: sharedWalletId,
        categoryId: catFreelanceId,
        type: 'income',
        amount: 4500000,
        note: 'Roommates monthly shared pool top-up',
        at: daysAgo(24, hour: 10),
      ),
      (
        id: '33333333-3333-4333-8333-333333333303',
        walletId: sharedWalletId,
        categoryId: catHousingId,
        type: 'expense',
        amount: 4200000,
        note: 'Apartment rent & building fee',
        at: daysAgo(23, hour: 14),
      ),
      (
        id: '33333333-3333-4333-8333-333333333304',
        walletId: sharedWalletId,
        categoryId: catHousingId,
        type: 'expense',
        amount: 680000,
        note: 'Electricity, water & fiber internet',
        at: daysAgo(20, hour: 18),
      ),
      (
        id: '33333333-3333-4333-8333-333333333305',
        walletId: personalWalletId,
        categoryId: catGroceriesId,
        type: 'expense',
        amount: 760000,
        note: 'Weekly supermarket groceries',
        at: daysAgo(18, hour: 19),
      ),
      (
        id: '33333333-3333-4333-8333-333333333306',
        walletId: personalWalletId,
        categoryId: catFoodId,
        type: 'expense',
        amount: 420000,
        note: 'Team lunch near office',
        at: daysAgo(16, hour: 12),
      ),
      (
        id: '33333333-3333-4333-8333-333333333307',
        walletId: personalWalletId,
        categoryId: catTransportId,
        type: 'expense',
        amount: 240000,
        note: 'Fuel & parking pass',
        at: daysAgo(15, hour: 8),
      ),
      (
        id: '33333333-3333-4333-8333-333333333308',
        walletId: personalWalletId,
        categoryId: catCoffeeId,
        type: 'expense',
        amount: 145000,
        note: 'Cold brew & working cafe',
        at: daysAgo(13, hour: 15),
      ),
      (
        id: '33333333-3333-4333-8333-333333333309',
        walletId: personalWalletId,
        categoryId: catFreelanceId,
        type: 'income',
        amount: 2200000,
        note: 'Weekend UI prototype freelance payout',
        at: daysAgo(11, hour: 16),
      ),
      (
        id: '33333333-3333-4333-8333-333333333310',
        walletId: personalWalletId,
        categoryId: catFoodId,
        type: 'expense',
        amount: 1180000,
        note: 'Pho, com tam & weekday dinners',
        at: daysAgo(9, hour: 20),
      ),
      (
        id: '33333333-3333-4333-8333-333333333311',
        walletId: sharedWalletId,
        categoryId: catGroceriesId,
        type: 'expense',
        amount: 890000,
        note: 'Shared household supplies & fruit',
        at: daysAgo(7, hour: 17),
      ),
      (
        id: '33333333-3333-4333-8333-333333333312',
        walletId: personalWalletId,
        categoryId: catEntertainmentId,
        type: 'expense',
        amount: 520000,
        note: 'Cinema tickets & board game night',
        at: daysAgo(5, hour: 21),
      ),
      (
        id: '33333333-3333-4333-8333-333333333313',
        walletId: personalWalletId,
        categoryId: catCoffeeId,
        type: 'expense',
        amount: 540000,
        note: 'Coffee beans & afternoon matcha',
        at: daysAgo(3, hour: 14),
      ),
      (
        id: '33333333-3333-4333-8333-333333333314',
        walletId: personalWalletId,
        categoryId: catFoodId,
        type: 'expense',
        amount: 1450000,
        note: 'Weekend hotpot with study group',
        at: daysAgo(2, hour: 19),
      ),
      (
        id: '33333333-3333-4333-8333-333333333315',
        walletId: personalWalletId,
        categoryId: catTransportId,
        type: 'expense',
        amount: 310000,
        note: 'Grab bike rides & metro card',
        at: daysAgo(1, hour: 9),
      ),
      (
        id: '33333333-3333-4333-8333-333333333316',
        walletId: personalWalletId,
        categoryId: catCoffeeId,
        type: 'expense',
        amount: 185000,
        note: 'Morning espresso & banh mi',
        at: daysAgo(0, hour: 8),
      ),
    ];

      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.wallets, sampleWallets);
        batch.insertAllOnConflictUpdate(
          _db.transactions,
          samples
              .map(
                (s) => TransactionsCompanion.insert(
                  id: s.id,
                  walletId: s.walletId,
                  categoryId: s.categoryId,
                  type: s.type,
                  amountMinor: s.amount,
                  note: Value(s.note),
                  occurredAtEpochMs: s.at.millisecondsSinceEpoch,
                  updatedAtEpochMs: s.at.millisecondsSinceEpoch,
                  syncStatus: const Value('synced'),
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }
}

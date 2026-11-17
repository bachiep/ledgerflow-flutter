import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/analytics/data/drift_analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/pages/analytics_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

void main() {
  group('DriftAnalyticsRepository', () {
    late AppDatabase db;
    late FixedClock clock;
    late DriftAnalyticsRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      clock = FixedClock(DateTime.utc(2026, 11, 18, 12, 0));
      final seeder = SampleDataSeeder(db, clock);
      await seeder.seedDefaultCategories();
      await db.upsertWalletAtomic(
        id: 'w1',
        name: 'Personal',
        currency: 'VND',
        initialBalanceMinor: 0,
        isShared: false,
        updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
        outboxId: 'o-w1',
      );
      repository = DriftAnalyticsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('aggregates monthly cashflow, share ratio, and budget alert levels via SQL', () async {
      final nov10 = DateTime.utc(2026, 11, 10, 9).millisecondsSinceEpoch;
      final nov12 = DateTime.utc(2026, 11, 12, 12).millisecondsSinceEpoch;
      final nov15 = DateTime.utc(2026, 11, 15, 18).millisecondsSinceEpoch;
      final oct28 = DateTime.utc(2026, 10, 28, 12).millisecondsSinceEpoch;

      // Income in Nov
      await db.upsertTransactionAtomic(
        id: 'tx-inc',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catSalaryId,
        type: 'income',
        amountMinor: 10000000,
        note: 'Salary',
        occurredAtEpochMs: nov10,
        updatedAtEpochMs: nov10,
        outboxId: 'o-1',
      );
      // Coffee budget is 800,000 -> spend 680,000 (85% = warning)
      await db.upsertTransactionAtomic(
        id: 'tx-coffee',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catCoffeeId,
        type: 'expense',
        amountMinor: 680000,
        note: 'Coffee beans',
        occurredAtEpochMs: nov12,
        updatedAtEpochMs: nov12,
        outboxId: 'o-2',
      );
      // Transport budget is 1,200,000 -> spend 1,320,000 (110% = exceeded)
      await db.upsertTransactionAtomic(
        id: 'tx-transport',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catTransportId,
        type: 'expense',
        amountMinor: 1320000,
        note: 'Flight + taxi',
        occurredAtEpochMs: nov15,
        updatedAtEpochMs: nov15,
        outboxId: 'o-3',
      );
      // Soft-deleted Nov expense (must be excluded)
      await db.upsertTransactionAtomic(
        id: 'tx-deleted',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catFoodId,
        type: 'expense',
        amountMinor: 500000,
        note: 'Cancelled',
        occurredAtEpochMs: nov15,
        updatedAtEpochMs: nov15,
        outboxId: 'o-4',
      );
      await db.softDeleteTransactionAtomic(
        transactionId: 'tx-deleted',
        deletedAtEpochMs: nov15 + 1000,
        outboxId: 'o-4-del',
      );
      // Previous month expense (must be excluded from Nov)
      await db.upsertTransactionAtomic(
        id: 'tx-oct',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catFoodId,
        type: 'expense',
        amountMinor: 900000,
        note: 'Oct food',
        occurredAtEpochMs: oct28,
        updatedAtEpochMs: oct28,
        outboxId: 'o-5',
      );

      final snapshot = await repository
          .watchMonthlyAnalytics(DateTime.utc(2026, 11, 1))
          .first;

      expect(snapshot.summary.totalIncomeMinor, 10000000);
      expect(snapshot.summary.totalExpenseMinor, 2000000);
      expect(snapshot.summary.netBalanceMinor, 8000000);
      expect(snapshot.summary.transactionCount, 3);
      expect(snapshot.categorySpends, hasLength(2));

      final topSpend = snapshot.categorySpends.first;
      expect(topSpend.categoryId, SampleDataSeeder.catTransportId);
      expect(topSpend.alertLevel, BudgetAlertLevel.exceeded);
      expect(topSpend.shareRatio, closeTo(0.66, 0.001));

      final secondSpend = snapshot.categorySpends.last;
      expect(secondSpend.categoryId, SampleDataSeeder.catCoffeeId);
      expect(secondSpend.alertLevel, BudgetAlertLevel.warning);
      expect(secondSpend.shareRatio, closeTo(0.34, 0.001));
    });
  });

  group('AnalyticsCubit', () {
    late _MockAnalyticsRepository mockRepo;
    late FixedClock clock;

    setUp(() {
      mockRepo = _MockAnalyticsRepository();
      clock = FixedClock(DateTime.utc(2026, 11, 18));
    });

    blocTest<AnalyticsCubit, AnalyticsState>(
      'emits AnalyticsEmpty when month has zero transactions, then AnalyticsLoaded after previousMonth()',
      setUp: () {
        when(() => mockRepo.watchMonthlyAnalytics(DateTime.utc(2026, 11, 1)))
            .thenAnswer(
          (_) => Stream.value(
            MonthlyAnalyticsSnapshot(
              summary: MonthlySummary(
                month: DateTime.utc(2026, 11, 1),
                totalIncomeMinor: 0,
                totalExpenseMinor: 0,
                transactionCount: 0,
              ),
              categorySpends: const [],
            ),
          ),
        );
        when(() => mockRepo.watchMonthlyAnalytics(DateTime.utc(2026, 10, 1)))
            .thenAnswer(
          (_) => Stream.value(
            MonthlyAnalyticsSnapshot(
              summary: MonthlySummary(
                month: DateTime.utc(2026, 10, 1),
                totalIncomeMinor: 500000,
                totalExpenseMinor: 200000,
                transactionCount: 2,
              ),
              categorySpends: const [
                CategorySpend(
                  categoryId: 'c1',
                  categoryName: 'Coffee',
                  iconName: 'local_cafe',
                  colorHex: 0xFFD97706,
                  spentMinor: 200000,
                  monthlyBudgetMinor: 200000,
                  shareRatio: 1.0,
                ),
              ],
            ),
          ),
        );
      },
      build: () => AnalyticsCubit(repository: mockRepo, clock: clock),
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.previousMonth();
      },
      expect: () => [
        AnalyticsEmpty(DateTime.utc(2026, 11, 1)),
        AnalyticsLoading(DateTime.utc(2026, 10, 1)),
        isA<AnalyticsLoaded>(),
      ],
    );

    blocTest<AnalyticsCubit, AnalyticsState>(
      'emits AnalyticsError on failure and recovers on retry()',
      setUp: () {
        var attempt = 0;
        when(() => mockRepo.watchMonthlyAnalytics(DateTime.utc(2026, 11, 1)))
            .thenAnswer((_) {
          attempt++;
          if (attempt == 1) {
            return Stream<MonthlyAnalyticsSnapshot>.error(
              Exception('Aggregation failed'),
            );
          }
          return Stream.value(
            MonthlyAnalyticsSnapshot(
              summary: MonthlySummary(
                month: DateTime.utc(2026, 11, 1),
                totalIncomeMinor: 100000,
                totalExpenseMinor: 0,
                transactionCount: 1,
              ),
              categorySpends: const [],
            ),
          );
        });
      },
      build: () => AnalyticsCubit(repository: mockRepo, clock: clock),
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.retry();
      },
      expect: () => [
        isA<AnalyticsError>(),
        AnalyticsLoading(DateTime.utc(2026, 11, 1)),
        isA<AnalyticsLoaded>(),
      ],
    );
  });

  testWidgets('AnalyticsPage displays donut breakdown and budget alert badges', (
    WidgetTester tester,
  ) async {
    final mockRepo = _MockAnalyticsRepository();
    final clock = FixedClock(DateTime.utc(2026, 11, 18));

    when(() => mockRepo.watchMonthlyAnalytics(DateTime.utc(2026, 11, 1)))
        .thenAnswer(
      (_) => Stream.value(
        MonthlyAnalyticsSnapshot(
          summary: MonthlySummary(
            month: DateTime.utc(2026, 11, 1),
            totalIncomeMinor: 5000000,
            totalExpenseMinor: 1500000,
            transactionCount: 3,
          ),
          categorySpends: const [
            CategorySpend(
              categoryId: 'c1',
              categoryName: 'Food & Dining',
              iconName: 'restaurant',
              colorHex: 0xFFEA580C,
              spentMinor: 900000,
              monthlyBudgetMinor: 1000000,
              shareRatio: 0.6,
            ),
            CategorySpend(
              categoryId: 'c2',
              categoryName: 'Coffee',
              iconName: 'local_cafe',
              colorHex: 0xFFD97706,
              spentMinor: 600000,
              monthlyBudgetMinor: 500000,
              shareRatio: 0.4,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider(
            create: (_) => AnalyticsCubit(repository: mockRepo, clock: clock),
            child: const AnalyticsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expense Breakdown'), findsOneWidget);
    expect(find.text('Category Budgets & Alerts'), findsOneWidget);
    expect(find.text('Near limit'), findsOneWidget);
    expect(find.text('Over budget'), findsOneWidget);
  });
}

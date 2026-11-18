import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:ledgerflow_flutter/core/theme/app_theme.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/analytics/data/drift_analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_repository.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/csv_statement_exporter.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/cubit/analytics_cubit.dart';
import 'package:ledgerflow_flutter/features/analytics/presentation/pages/analytics_page.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
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
      repository = DriftAnalyticsRepository(db, clock: clock);
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

    test('aggregates 6-month trailing income and expense trend via SQL', () async {
      final jun = DateTime.utc(2026, 6, 15, 10).millisecondsSinceEpoch;
      final aug = DateTime.utc(2026, 8, 20, 14).millisecondsSinceEpoch;
      final nov = DateTime.utc(2026, 11, 5, 9).millisecondsSinceEpoch;
      final mayExcluded = DateTime.utc(2026, 5, 31, 23).millisecondsSinceEpoch;

      await db.upsertTransactionAtomic(
        id: 'tx-may',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catSalaryId,
        type: 'income',
        amountMinor: 9999999,
        note: 'Too old',
        occurredAtEpochMs: mayExcluded,
        updatedAtEpochMs: mayExcluded,
        outboxId: 'o-may',
      );
      await db.upsertTransactionAtomic(
        id: 'tx-jun',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catSalaryId,
        type: 'income',
        amountMinor: 12000000,
        note: 'June pay',
        occurredAtEpochMs: jun,
        updatedAtEpochMs: jun,
        outboxId: 'o-jun',
      );
      await db.upsertTransactionAtomic(
        id: 'tx-aug',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catFoodId,
        type: 'expense',
        amountMinor: 2500000,
        note: 'Aug expense',
        occurredAtEpochMs: aug,
        updatedAtEpochMs: aug,
        outboxId: 'o-aug',
      );
      await db.upsertTransactionAtomic(
        id: 'tx-nov',
        walletId: 'w1',
        categoryId: SampleDataSeeder.catCoffeeId,
        type: 'expense',
        amountMinor: 600000,
        note: 'Nov coffee',
        occurredAtEpochMs: nov,
        updatedAtEpochMs: nov,
        outboxId: 'o-nov',
      );

      final snapshot = await repository
          .watchMonthlyAnalytics(DateTime.utc(2026, 11, 1))
          .first;

      expect(snapshot.sixMonthTrend, hasLength(6));
      expect(snapshot.sixMonthTrend.first.month, DateTime.utc(2026, 6, 1));
      expect(snapshot.sixMonthTrend.first.incomeMinor, 12000000);
      expect(snapshot.sixMonthTrend[1].incomeMinor, 0);
      expect(snapshot.sixMonthTrend[2].expenseMinor, 2500000);
      expect(snapshot.sixMonthTrend.last.month, DateTime.utc(2026, 11, 1));
      expect(snapshot.sixMonthTrend.last.expenseMinor, 600000);
    });
  });

  group('CsvStatementExporter', () {
    test('formats RFC-4180 CSV and neutralizes spreadsheet formula prefixes (=, +, -, @)', () {
      final entries = [
        TransactionEntry(
          id: 'tx-1',
          walletId: 'w1',
          walletName: 'Main, "Personal"',
          walletCurrency: 'VND',
          categoryId: 'c1',
          categoryName: 'Food & Dining',
          categoryIconName: 'restaurant',
          categoryColorHex: 0xFFEA580C,
          type: TransactionType.expense,
          amountMinor: 150000,
          note: '=SUM(A1:A2)',
          occurredAt: DateTime.utc(2026, 11, 10, 8, 30),
          updatedAt: DateTime.utc(2026, 11, 10, 8, 30),
          syncStatus: SyncStatus.synced,
        ),
        TransactionEntry(
          id: 'tx-2',
          walletId: 'w1',
          walletName: '+cmd',
          walletCurrency: 'USD',
          categoryId: 'c2',
          categoryName: '-danger',
          categoryIconName: 'local_cafe',
          categoryColorHex: 0xFFD97706,
          type: TransactionType.income,
          amountMinor: 1250,
          note: '@import, "quoted"',
          occurredAt: DateTime.utc(2026, 11, 12, 9, 0),
          updatedAt: DateTime.utc(2026, 11, 12, 9, 0),
          syncStatus: SyncStatus.pending,
        ),
      ];

      final result = CsvStatementExporter.build(entries);
      expect(result.rowCount, 2);
      expect(result.lines, hasLength(3));
      expect(result.lines.first, CsvStatementExporter.headerRow);
      expect(
        result.lines[1],
        '2026-11-10 08:30 UTC,expense,Food & Dining,"Main, ""Personal""",\'=SUM(A1:A2),150000,VND,synced',
      );
      expect(
        result.lines[2],
        '2026-11-12 09:00 UTC,income,\'-danger,\'+cmd,"\'@import, ""quoted""",12.50,USD,pending',
      );
      expect(CsvStatementExporter.escapeField('  =1+1'), "'  =1+1");
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

  testWidgets('AnalyticsPage displays 6-month trend, donut breakdown, and budget alert badges', (
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
          sixMonthTrend: [
            MonthlyCashflowPoint(
              month: DateTime.utc(2026, 10, 1),
              incomeMinor: 4000000,
              expenseMinor: 2000000,
            ),
            MonthlyCashflowPoint(
              month: DateTime.utc(2026, 11, 1),
              incomeMinor: 5000000,
              expenseMinor: 1500000,
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

    expect(find.text('6-Month Cashflow Trend'), findsOneWidget);
    expect(find.text('Category Budgets & Alerts'), findsOneWidget);
    expect(find.text('Near limit'), findsOneWidget);
    expect(find.text('Over budget'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Expense Breakdown'),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Expense Breakdown'), findsOneWidget);
  });

  testWidgets(
    'BudgetEditorSheet updates SQLite budget and refreshes alert badge immediately; CsvExportSheet copies CSV',
    (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final clock = FixedClock(DateTime.utc(2026, 11, 18, 12));
      late DriftAnalyticsRepository repo;
      late AnalyticsCubit cubit;
      await tester.runAsync(() async {
        await SampleDataSeeder(db, clock).seedDefaultCategories();
        await db.upsertWalletAtomic(
          id: 'w1',
          name: 'Main Wallet',
          currency: 'VND',
          initialBalanceMinor: 5000000,
          isShared: false,
          updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
          outboxId: 'o-w1',
        );
        await db.upsertTransactionAtomic(
          id: 'tx-coffee-1',
          walletId: 'w1',
          categoryId: SampleDataSeeder.catCoffeeId,
          type: 'expense',
          amountMinor: 680000,
          note: '=Espresso formula test',
          occurredAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
          updatedAtEpochMs: clock.nowUtc().millisecondsSinceEpoch,
          outboxId: 'o-tx-1',
        );
        repo = DriftAnalyticsRepository(db, clock: clock);
        cubit = AnalyticsCubit(repository: repo, clock: clock);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      addTearDown(() async {
        await cubit.close();
        await db.close();
      });

      String? copiedClipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedClipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BlocProvider<AnalyticsCubit>.value(
              value: cubit,
              child: const AnalyticsPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // Initially 680k / 800k = 85% -> Near limit
      final rowFinder =
          find.byKey(const Key('budget_row_${SampleDataSeeder.catCoffeeId}'));
      await tester.scrollUntilVisible(rowFinder, 200);
      await tester.pumpAndSettle();
      expect(find.text('Near limit'), findsOneWidget);

      await tester.tap(rowFinder);
      await tester.pumpAndSettle();

      expect(find.text('Edit Monthly Budget'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('budget_amount_field')),
        '500000',
      );
      await tester.tap(find.byKey(const Key('save_budget_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // Immediately transitions from Near limit -> Over budget (680k / 500k = 136%)
      expect(find.text('Over budget'), findsOneWidget);
      expect(find.text('Near limit'), findsNothing);

      // Export CSV flow
      final exportBtn = find.byKey(const Key('export_csv_button'));
      await tester.scrollUntilVisible(exportBtn, -200);
      await tester.pumpAndSettle();
      await tester.tap(exportBtn);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline CSV Statement'), findsOneWidget);
      expect(find.byKey(const Key('csv_preview_box')), findsOneWidget);

      await tester.tap(find.byKey(const Key('copy_csv_button')));
      await tester.pumpAndSettle();

      expect(copiedClipboardText, isNotNull);
      expect(copiedClipboardText, contains("'=Espresso formula test"));
      expect(find.text('Copied 1 Rows to Clipboard'), findsOneWidget);
    },
  );
}

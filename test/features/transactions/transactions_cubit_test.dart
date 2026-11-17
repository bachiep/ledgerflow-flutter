import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_filter_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transactions_cubit.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransactionRepository extends Mock
    implements TransactionRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockTransactionRepository txRepo;
  late _MockWalletRepository walletRepo;
  late TransactionFilterCubit filterCubit;

  final sampleWallet = Wallet(
    id: 'w1',
    name: 'Personal',
    currency: 'VND',
    initialBalanceMinor: 500000,
    currentBalanceMinor: 350000,
    isShared: false,
    updatedAt: DateTime.utc(2026, 11, 18),
    syncStatus: SyncStatus.synced,
  );

  const sampleCategory = CategoryItem(
    id: 'c1',
    name: 'Food',
    type: TransactionType.expense,
    iconName: 'restaurant',
    colorHex: 0xFFEA580C,
    monthlyBudgetMinor: 1000000,
  );

  final sampleEntry = TransactionEntry(
    id: 't1',
    walletId: 'w1',
    walletName: 'Personal',
    walletCurrency: 'VND',
    categoryId: 'c1',
    categoryName: 'Food',
    categoryIconName: 'restaurant',
    categoryColorHex: 0xFFEA580C,
    type: TransactionType.expense,
    amountMinor: 150000,
    note: 'Bun cha',
    occurredAt: DateTime.utc(2026, 11, 18),
    updatedAt: DateTime.utc(2026, 11, 18),
    syncStatus: SyncStatus.pending,
  );

  setUpAll(() {
    registerFallbackValue(const TransactionFilter());
  });

  setUp(() {
    txRepo = _MockTransactionRepository();
    walletRepo = _MockWalletRepository();
    filterCubit = TransactionFilterCubit();

    when(() => walletRepo.watchWallets())
        .thenAnswer((_) => Stream.value([sampleWallet]));
    when(() => txRepo.watchCategories(type: any(named: 'type')))
        .thenAnswer((_) => Stream.value([sampleCategory]));
  });

  tearDown(() async {
    await filterCubit.close();
  });

  group('TransactionsCubit', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'emits TransactionsEmpty when stream emits empty list',
      setUp: () {
        when(() => txRepo.watchTransactions(any()))
            .thenAnswer((_) => Stream.value(const []));
      },
      build: () => TransactionsCubit(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
        filterCubit: filterCubit,
      ),
      expect: () => [
        isA<TransactionsEmpty>(),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'emits TransactionsLoaded with computed income and expense totals',
      setUp: () {
        when(() => txRepo.watchTransactions(any()))
            .thenAnswer((_) => Stream.value([sampleEntry]));
      },
      build: () => TransactionsCubit(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
        filterCubit: filterCubit,
      ),
      expect: () => [
        isA<TransactionsLoaded>()
            .having((s) => s.transactions.length, 'count', 1)
            .having((s) => s.filteredExpenseMinor, 'expense', 150000)
            .having((s) => s.totalWalletBalanceMinor, 'balance', 350000),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'emits TransactionsError when stream fails and recovers on start()',
      setUp: () {
        var callCount = 0;
        when(() => txRepo.watchTransactions(any())).thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return Stream<List<TransactionEntry>>.error(
              Exception('SQLite read failed'),
            );
          }
          return Stream.value([sampleEntry]);
        });
      },
      build: () => TransactionsCubit(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
        filterCubit: filterCubit,
      ),
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.start();
      },
      expect: () => [
        isA<TransactionsError>(),
        const TransactionsLoading(),
        isA<TransactionsLoaded>(),
      ],
    );

    test('deleteTransaction delegates soft-delete to repository', () async {
      when(() => txRepo.watchTransactions(any()))
          .thenAnswer((_) => Stream.value([sampleEntry]));
      when(() => txRepo.softDeleteTransaction('t1'))
          .thenAnswer((_) async => const Success(null));

      final cubit = TransactionsCubit(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
        filterCubit: filterCubit,
      );
      addTearDown(cubit.close);

      final deleted = await cubit.deleteTransaction('t1');
      expect(deleted, isTrue);
      verify(() => txRepo.softDeleteTransaction('t1')).called(1);
    });
  });
}

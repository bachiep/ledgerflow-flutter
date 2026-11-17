import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_filter_cubit.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_search_bloc.dart';

void main() {
  group('TransactionSearchBloc', () {
    blocTest<TransactionSearchBloc, String>(
      'debounces rapid queries and cancels stale searches via restartable()',
      build: () => TransactionSearchBloc(
        debounceDuration: const Duration(milliseconds: 40),
      ),
      act: (bloc) async {
        bloc.add(const SearchQueryChanged('c'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const SearchQueryChanged('co'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const SearchQueryChanged('  coffee  '));
      },
      wait: const Duration(milliseconds: 80),
      expect: () => ['coffee'],
    );

    blocTest<TransactionSearchBloc, String>(
      'emits empty string immediately when cleared or blank',
      build: () => TransactionSearchBloc(
        debounceDuration: const Duration(milliseconds: 40),
      ),
      act: (bloc) async {
        bloc.add(const SearchQueryChanged('lunch'));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        bloc.add(const SearchCleared());
      },
      expect: () => ['lunch', ''],
    );
  });

  group('TransactionFilterCubit', () {
    blocTest<TransactionFilterCubit, TransactionFilter>(
      'updates and clears type, category, month, and search query',
      build: TransactionFilterCubit.new,
      act: (cubit) => cubit
        ..selectType(TransactionType.expense)
        ..selectCategory('cat-food')
        ..selectMonth(DateTime(2026, 11, 18))
        ..setSearchQuery('pho')
        ..clearAll(),
      expect: () => [
        const TransactionFilter(type: TransactionType.expense),
        const TransactionFilter(
          type: TransactionType.expense,
          categoryId: 'cat-food',
        ),
        TransactionFilter(
          type: TransactionType.expense,
          categoryId: 'cat-food',
          month: DateTime.utc(2026, 11, 1),
        ),
        TransactionFilter(
          type: TransactionType.expense,
          categoryId: 'cat-food',
          month: DateTime.utc(2026, 11, 1),
          searchQuery: 'pho',
        ),
        const TransactionFilter(),
      ],
    );
  });
}

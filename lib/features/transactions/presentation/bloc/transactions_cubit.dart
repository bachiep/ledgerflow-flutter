import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';
import 'package:ledgerflow_flutter/features/transactions/presentation/bloc/transaction_filter_cubit.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet_repository.dart';

sealed class TransactionsState extends Equatable {
  const TransactionsState();

  @override
  List<Object?> get props => [];
}

final class TransactionsLoading extends TransactionsState {
  const TransactionsLoading();
}

final class TransactionsLoaded extends TransactionsState {
  const TransactionsLoaded({
    required this.transactions,
    required this.wallets,
    required this.categories,
    required this.filter,
  });

  final List<TransactionEntry> transactions;
  final List<Wallet> wallets;
  final List<CategoryItem> categories;
  final TransactionFilter filter;

  int get totalWalletBalanceMinor =>
      wallets.fold<int>(0, (sum, w) => sum + w.currentBalanceMinor);

  int get filteredIncomeMinor => transactions
      .where((t) => t.type == TransactionType.income)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);

  int get filteredExpenseMinor => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);

  @override
  List<Object?> get props => [transactions, wallets, categories, filter];
}

final class TransactionsEmpty extends TransactionsState {
  const TransactionsEmpty({
    required this.wallets,
    required this.categories,
    required this.filter,
  });

  final List<Wallet> wallets;
  final List<CategoryItem> categories;
  final TransactionFilter filter;

  bool get hasActiveFilters => filter.hasActiveFilters;

  @override
  List<Object?> get props => [wallets, categories, filter];
}

final class TransactionsError extends TransactionsState {
  const TransactionsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    required TransactionRepository transactionRepository,
    required WalletRepository walletRepository,
    required TransactionFilterCubit filterCubit,
  })  : _transactionRepository = transactionRepository,
        _walletRepository = walletRepository,
        _filterCubit = filterCubit,
        super(const TransactionsLoading()) {
    start();
  }

  final TransactionRepository _transactionRepository;
  final WalletRepository _walletRepository;
  final TransactionFilterCubit _filterCubit;

  StreamSubscription<TransactionFilter>? _filterSub;
  StreamSubscription<List<TransactionEntry>>? _txSub;
  StreamSubscription<List<Wallet>>? _walletSub;
  StreamSubscription<List<CategoryItem>>? _categorySub;

  List<Wallet> _wallets = const [];
  List<CategoryItem> _categories = const [];
  List<TransactionEntry>? _transactions;
  bool _walletsLoaded = false;
  bool _categoriesLoaded = false;

  void start() {
    emit(const TransactionsLoading());
    _walletsLoaded = false;
    _categoriesLoaded = false;
    _transactions = null;
    _filterSub?.cancel();
    _walletSub?.cancel();
    _categorySub?.cancel();

    _walletSub = _walletRepository.watchWallets().listen(
      (wallets) {
        _wallets = wallets;
        _walletsLoaded = true;
        _emitSnapshot();
      },
      onError: (Object error, StackTrace _) {
        emit(TransactionsError(error.toString()));
      },
    );

    _categorySub = _transactionRepository.watchCategories().listen(
      (categories) {
        _categories = categories;
        _categoriesLoaded = true;
        _emitSnapshot();
      },
      onError: (Object error, StackTrace _) {
        emit(TransactionsError(error.toString()));
      },
    );

    _subscribeToTransactions(_filterCubit.state);
    _filterSub = _filterCubit.stream.listen(_subscribeToTransactions);
  }

  void _subscribeToTransactions(TransactionFilter filter) {
    _txSub?.cancel();
    _txSub = _transactionRepository.watchTransactions(filter).listen(
      (items) {
        _transactions = items;
        _emitSnapshot();
      },
      onError: (Object error, StackTrace _) {
        emit(TransactionsError(error.toString()));
      },
    );
  }

  void _emitSnapshot() {
    final txs = _transactions;
    if (txs == null || !_walletsLoaded || !_categoriesLoaded) {
      return;
    }
    if (txs.isEmpty) {
      emit(
        TransactionsEmpty(
          wallets: _wallets,
          categories: _categories,
          filter: _filterCubit.state,
        ),
      );
      return;
    }

    emit(
      TransactionsLoaded(
        transactions: txs,
        wallets: _wallets,
        categories: _categories,
        filter: _filterCubit.state,
      ),
    );
  }

  Future<bool> deleteTransaction(String id) async {
    final result = await _transactionRepository.softDeleteTransaction(id);
    return result.isSuccess;
  }

  @override
  Future<void> close() async {
    await _filterSub?.cancel();
    await _txSub?.cancel();
    await _walletSub?.cancel();
    await _categorySub?.cancel();
    return super.close();
  }
}

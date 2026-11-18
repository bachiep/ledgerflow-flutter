import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet_repository.dart';

sealed class WalletsState extends Equatable {
  const WalletsState();

  @override
  List<Object?> get props => [];
}

final class WalletsLoading extends WalletsState {
  const WalletsLoading();
}

final class WalletsLoaded extends WalletsState {
  const WalletsLoaded(this.wallets);

  final List<Wallet> wallets;

  int get totalBalanceMinor =>
      wallets.fold<int>(0, (sum, w) => sum + w.currentBalanceMinor);

  @override
  List<Object?> get props => [wallets];
}

final class WalletsEmpty extends WalletsState {
  const WalletsEmpty();
}

final class WalletsError extends WalletsState {
  const WalletsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class WalletsCubit extends Cubit<WalletsState> {
  WalletsCubit(this._repository) : super(const WalletsLoading()) {
    start();
  }

  final WalletRepository _repository;
  StreamSubscription<List<Wallet>>? _subscription;

  void start() {
    emit(const WalletsLoading());
    _subscription?.cancel();
    _subscription = _repository.watchWallets().listen(
      (wallets) {
        if (wallets.isEmpty) {
          emit(const WalletsEmpty());
        } else {
          emit(WalletsLoaded(wallets));
        }
      },
      onError: (Object error, StackTrace _) {
        emit(WalletsError(error.toString()));
      },
    );
  }

  Future<bool> createWallet({
    required String name,
    String currency = 'VND',
    int initialBalanceMinor = 0,
    bool isShared = false,
  }) async {
    final result = await _repository.createWallet(
      name: name,
      currency: currency,
      initialBalanceMinor: initialBalanceMinor,
      isShared: isShared,
    );
    return result.isSuccess;
  }

  Future<Result<void>> transferBetweenWallets({
    required String sourceWalletId,
    required String destinationWalletId,
    required int amountMinor,
    String note = '',
  }) async {
    return _repository.transferBetweenWallets(
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      amountMinor: amountMinor,
      note: note,
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

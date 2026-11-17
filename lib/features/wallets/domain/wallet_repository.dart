import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';

abstract interface class WalletRepository {
  Stream<List<Wallet>> watchWallets();

  Future<Result<Wallet>> createWallet({
    required String name,
    String currency = 'VND',
    int initialBalanceMinor = 0,
    bool isShared = false,
  });
}

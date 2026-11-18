import 'package:ledgerflow_flutter/core/database/app_database.dart';
import 'package:ledgerflow_flutter/core/error/failure.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet.dart';
import 'package:ledgerflow_flutter/features/wallets/domain/wallet_repository.dart';
import 'package:uuid/uuid.dart';

class DriftWalletRepository implements WalletRepository {
  DriftWalletRepository({
    required AppDatabase database,
    required AppClock clock,
    Uuid? uuid,
  })  : _db = database,
        _clock = clock,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AppClock _clock;
  final Uuid _uuid;

  @override
  Stream<List<Wallet>> watchWallets() {
    final now = _clock.nowUtc();
    final monthFrom =
        DateTime.utc(now.year, now.month, 1).millisecondsSinceEpoch;
    final monthTo =
        DateTime.utc(now.year, now.month + 1, 1).millisecondsSinceEpoch;

    return _db
        .watchWalletsWithBalance(
          monthFromEpochMs: monthFrom,
          monthToEpochMs: monthTo,
        )
        .map(
          (rows) => rows
              .map(
                (row) => Wallet(
                  id: row.wallet.id,
                  name: row.wallet.name,
                  currency: row.wallet.currency,
                  initialBalanceMinor: row.wallet.initialBalanceMinor,
                  currentBalanceMinor: row.currentBalanceMinor,
                  isShared: row.wallet.isShared,
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(
                    row.wallet.updatedAtEpochMs,
                    isUtc: true,
                  ),
                  syncStatus: SyncStatus.fromStorage(row.wallet.syncStatus),
                  monthlyInflowMinor: row.monthlyInflowMinor,
                  monthlyOutflowMinor: row.monthlyOutflowMinor,
                  monthlyTxCount: row.monthlyTxCount,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Wallet>> createWallet({
    required String name,
    String currency = 'VND',
    int initialBalanceMinor = 0,
    bool isShared = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(ValidationFailure('Wallet name cannot be empty.'));
    }

    try {
      final now = _clock.nowUtc();
      final walletId = _uuid.v4();
      await _db.upsertWalletAtomic(
        id: walletId,
        name: trimmed,
        currency: currency.toUpperCase(),
        initialBalanceMinor: initialBalanceMinor,
        isShared: isShared,
        updatedAtEpochMs: now.millisecondsSinceEpoch,
        outboxId: _uuid.v4(),
      );

      return Success(
        Wallet(
          id: walletId,
          name: trimmed,
          currency: currency.toUpperCase(),
          initialBalanceMinor: initialBalanceMinor,
          currentBalanceMinor: initialBalanceMinor,
          isShared: isShared,
          updatedAt: now,
          syncStatus: SyncStatus.pending,
        ),
      );
    } catch (error) {
      return Err(DatabaseFailure('Failed to save wallet.', cause: error));
    }
  }

  @override
  Future<Result<void>> transferBetweenWallets({
    required String sourceWalletId,
    required String destinationWalletId,
    required int amountMinor,
    String note = '',
  }) async {
    if (sourceWalletId == destinationWalletId) {
      return const Err(
        ValidationFailure('Source and destination wallets must be different.'),
      );
    }
    if (amountMinor <= 0) {
      return const Err(
        ValidationFailure('Transfer amount must be greater than 0.'),
      );
    }

    try {
      final now = _clock.nowUtc();
      await _db.transferAtomic(
        sourceWalletId: sourceWalletId,
        destinationWalletId: destinationWalletId,
        amountMinor: amountMinor,
        note: note,
        occurredAtEpochMs: now.millisecondsSinceEpoch,
        sourceTxId: _uuid.v4(),
        destinationTxId: _uuid.v4(),
        sourceOutboxId: _uuid.v4(),
        destinationOutboxId: _uuid.v4(),
      );
      return const Success(null);
    } on StateError catch (error) {
      return Err(ValidationFailure(error.message));
    } on ArgumentError catch (error) {
      return Err(ValidationFailure(error.message.toString()));
    } catch (error) {
      return Err(
        DatabaseFailure('Failed to complete wallet transfer.', cause: error),
      );
    }
  }
}

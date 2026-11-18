import 'package:equatable/equatable.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';

class Wallet extends Equatable {
  const Wallet({
    required this.id,
    required this.name,
    required this.currency,
    required this.initialBalanceMinor,
    required this.currentBalanceMinor,
    required this.isShared,
    required this.updatedAt,
    required this.syncStatus,
    this.monthlyInflowMinor = 0,
    this.monthlyOutflowMinor = 0,
    this.monthlyTxCount = 0,
  });

  final String id;
  final String name;
  final String currency;
  final int initialBalanceMinor;
  final int currentBalanceMinor;
  final bool isShared;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final int monthlyInflowMinor;
  final int monthlyOutflowMinor;
  final int monthlyTxCount;

  int get monthlyNetDeltaMinor => monthlyInflowMinor - monthlyOutflowMinor;

  @override
  List<Object?> get props => [
        id,
        name,
        currency,
        initialBalanceMinor,
        currentBalanceMinor,
        isShared,
        updatedAt,
        syncStatus,
        monthlyInflowMinor,
        monthlyOutflowMinor,
        monthlyTxCount,
      ];
}

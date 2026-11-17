import 'package:equatable/equatable.dart';
import 'package:ledgerflow_flutter/core/models/sync_status.dart';

enum TransactionType {
  income,
  expense;

  static TransactionType fromStorage(String raw) {
    return raw.toLowerCase() == 'income'
        ? TransactionType.income
        : TransactionType.expense;
  }

  String get storageValue => name;
}

class CategoryItem extends Equatable {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.colorHex,
    required this.monthlyBudgetMinor,
  });

  final String id;
  final String name;
  final TransactionType type;
  final String iconName;
  final int colorHex;
  final int monthlyBudgetMinor;

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        iconName,
        colorHex,
        monthlyBudgetMinor,
      ];
}

class TransactionEntry extends Equatable {
  const TransactionEntry({
    required this.id,
    required this.walletId,
    required this.walletName,
    required this.walletCurrency,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconName,
    required this.categoryColorHex,
    required this.type,
    required this.amountMinor,
    required this.note,
    required this.occurredAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  final String id;
  final String walletId;
  final String walletName;
  final String walletCurrency;
  final String categoryId;
  final String categoryName;
  final String categoryIconName;
  final int categoryColorHex;
  final TransactionType type;
  final int amountMinor;
  final String note;
  final DateTime occurredAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  @override
  List<Object?> get props => [
        id,
        walletId,
        walletName,
        walletCurrency,
        categoryId,
        categoryName,
        categoryIconName,
        categoryColorHex,
        type,
        amountMinor,
        note,
        occurredAt,
        updatedAt,
        syncStatus,
      ];
}

class TransactionFilter extends Equatable {
  const TransactionFilter({
    this.walletId,
    this.categoryId,
    this.type,
    this.month,
    this.searchQuery = '',
  });

  final String? walletId;
  final String? categoryId;
  final TransactionType? type;
  final DateTime? month;
  final String searchQuery;

  bool get hasActiveFilters =>
      walletId != null ||
      categoryId != null ||
      type != null ||
      month != null ||
      searchQuery.trim().isNotEmpty;

  TransactionFilter copyWith({
    String? walletId,
    bool clearWalletId = false,
    String? categoryId,
    bool clearCategoryId = false,
    TransactionType? type,
    bool clearType = false,
    DateTime? month,
    bool clearMonth = false,
    String? searchQuery,
  }) {
    return TransactionFilter(
      walletId: clearWalletId ? null : (walletId ?? this.walletId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      type: clearType ? null : (type ?? this.type),
      month: clearMonth ? null : (month ?? this.month),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [walletId, categoryId, type, month, searchQuery];
}

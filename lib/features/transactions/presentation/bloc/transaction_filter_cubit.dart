import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';

class TransactionFilterCubit extends Cubit<TransactionFilter> {
  TransactionFilterCubit({TransactionFilter? initialFilter})
      : super(initialFilter ?? const TransactionFilter());

  void selectType(TransactionType? type) {
    if (type == null) {
      emit(state.copyWith(clearType: true));
    } else {
      emit(state.copyWith(type: type));
    }
  }

  void selectCategory(String? categoryId) {
    if (categoryId == null) {
      emit(state.copyWith(clearCategoryId: true));
    } else {
      emit(state.copyWith(categoryId: categoryId));
    }
  }

  void selectWallet(String? walletId) {
    if (walletId == null) {
      emit(state.copyWith(clearWalletId: true));
    } else {
      emit(state.copyWith(walletId: walletId));
    }
  }

  void selectMonth(DateTime? month) {
    if (month == null) {
      emit(state.copyWith(clearMonth: true));
    } else {
      emit(state.copyWith(month: DateTime.utc(month.year, month.month, 1)));
    }
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void clearAll() {
    emit(const TransactionFilter());
  }
}

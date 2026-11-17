import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_models.dart';
import 'package:ledgerflow_flutter/features/transactions/domain/transaction_repository.dart';

sealed class TransactionFormState extends Equatable {
  const TransactionFormState();

  @override
  List<Object?> get props => [];
}

final class TransactionFormIdle extends TransactionFormState {
  const TransactionFormIdle();
}

final class TransactionFormSubmitting extends TransactionFormState {
  const TransactionFormSubmitting();
}

final class TransactionFormSuccess extends TransactionFormState {
  const TransactionFormSuccess(this.transactionId);

  final String transactionId;

  @override
  List<Object?> get props => [transactionId];
}

final class TransactionFormFailure extends TransactionFormState {
  const TransactionFormFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit(this._repository) : super(const TransactionFormIdle());

  final TransactionRepository _repository;

  Future<void> submit({
    String? existingId,
    required String walletId,
    required String categoryId,
    required TransactionType type,
    required int amountMinor,
    required String note,
    required DateTime occurredAt,
  }) async {
    emit(const TransactionFormSubmitting());
    final result = await _repository.saveTransaction(
      existingId: existingId,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amountMinor: amountMinor,
      note: note,
      occurredAt: occurredAt,
    );
    result.fold(
      onSuccess: (id) => emit(TransactionFormSuccess(id)),
      onFailure: (failure) => emit(TransactionFormFailure(failure.message)),
    );
  }
}

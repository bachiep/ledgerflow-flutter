import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_repository.dart';

sealed class SyncInspectorState extends Equatable {
  const SyncInspectorState();

  @override
  List<Object?> get props => [];
}

final class SyncInspectorLoading extends SyncInspectorState {
  const SyncInspectorLoading();
}

final class SyncInspectorLoaded extends SyncInspectorState {
  const SyncInspectorLoaded(this.items);

  final List<SyncOutboxItem> items;

  int get pendingCount => items.where((i) => !i.isProcessed).length;
  int get syncedCount => items.where((i) => i.isProcessed).length;

  @override
  List<Object?> get props => [items];
}

final class SyncInspectorEmpty extends SyncInspectorState {
  const SyncInspectorEmpty();
}

final class SyncInspectorError extends SyncInspectorState {
  const SyncInspectorError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class SyncInspectorCubit extends Cubit<SyncInspectorState> {
  SyncInspectorCubit(this._repository) : super(const SyncInspectorLoading()) {
    start();
  }

  final SyncRepository _repository;
  StreamSubscription<List<SyncOutboxItem>>? _subscription;

  void start() {
    emit(const SyncInspectorLoading());
    _subscription?.cancel();
    _subscription = _repository.watchOutboxItems().listen(
      (items) {
        if (items.isEmpty) {
          emit(const SyncInspectorEmpty());
        } else {
          emit(SyncInspectorLoaded(items));
        }
      },
      onError: (Object error, StackTrace _) {
        emit(SyncInspectorError(error.toString()));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

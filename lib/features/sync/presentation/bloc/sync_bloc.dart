import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/auth/domain/auth_repository.dart';
import 'package:ledgerflow_flutter/features/sync/domain/network_connectivity.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_models.dart';
import 'package:ledgerflow_flutter/features/sync/domain/sync_repository.dart';

sealed class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

final class SyncStarted extends SyncEvent {
  const SyncStarted();
}

final class SyncRequested extends SyncEvent {
  const SyncRequested();
}

final class SimulateOfflineToggled extends SyncEvent {
  const SimulateOfflineToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

final class _PendingCountChanged extends SyncEvent {
  const _PendingCountChanged(this.pendingCount);

  final int pendingCount;

  @override
  List<Object?> get props => [pendingCount];
}

sealed class SyncState extends Equatable {
  const SyncState({
    required this.pendingCount,
    required this.simulateOffline,
    this.lastSyncedAt,
  });

  final int pendingCount;
  final bool simulateOffline;
  final DateTime? lastSyncedAt;

  @override
  List<Object?> get props => [pendingCount, simulateOffline, lastSyncedAt];
}

final class SyncIdle extends SyncState {
  const SyncIdle({
    required super.pendingCount,
    required super.simulateOffline,
    super.lastSyncedAt,
  });
}

final class SyncInProgress extends SyncState {
  const SyncInProgress({
    required super.pendingCount,
    required super.simulateOffline,
    super.lastSyncedAt,
  });
}

final class SyncSuccess extends SyncState {
  const SyncSuccess({
    required this.summary,
    required super.pendingCount,
    required super.simulateOffline,
    super.lastSyncedAt,
  });

  final SyncRunSummary summary;

  @override
  List<Object?> get props => [summary, ...super.props];
}

final class SyncFailureState extends SyncState {
  const SyncFailureState({
    required this.message,
    required super.pendingCount,
    required super.simulateOffline,
    super.lastSyncedAt,
  });

  final String message;

  @override
  List<Object?> get props => [message, ...super.props];
}

/// Manages background outbox push and delta pull using [droppable] concurrency.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc({
    required SyncRepository syncRepository,
    required AuthRepository authRepository,
    required NetworkConnectivity connectivity,
  })  : _syncRepository = syncRepository,
        _authRepository = authRepository,
        _connectivity = connectivity,
        super(const SyncIdle(pendingCount: 0, simulateOffline: false)) {
    on<SyncStarted>(_onStarted);
    on<SyncRequested>(_onSyncRequested, transformer: droppable());
    on<SimulateOfflineToggled>(_onSimulateOfflineToggled);
    on<_PendingCountChanged>(_onPendingCountChanged);
  }

  final SyncRepository _syncRepository;
  final AuthRepository _authRepository;
  final NetworkConnectivity _connectivity;

  StreamSubscription<int>? _pendingSub;
  StreamSubscription<bool>? _connectivitySub;

  void _onStarted(SyncStarted event, Emitter<SyncState> emit) {
    _pendingSub?.cancel();
    _pendingSub = _syncRepository.watchPendingOutboxCount().listen((count) {
      if (!isClosed) {
        add(_PendingCountChanged(count));
      }
    });

    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onIsOnlineChanged.listen((online) {
      if (!isClosed && online && !state.simulateOffline && state.pendingCount > 0) {
        add(const SyncRequested());
      }
    });
  }

  void _onPendingCountChanged(
    _PendingCountChanged event,
    Emitter<SyncState> emit,
  ) {
    switch (state) {
      case SyncIdle(:final simulateOffline, :final lastSyncedAt):
        emit(
          SyncIdle(
            pendingCount: event.pendingCount,
            simulateOffline: simulateOffline,
            lastSyncedAt: lastSyncedAt,
          ),
        );
      case SyncInProgress(:final simulateOffline, :final lastSyncedAt):
        emit(
          SyncInProgress(
            pendingCount: event.pendingCount,
            simulateOffline: simulateOffline,
            lastSyncedAt: lastSyncedAt,
          ),
        );
      case SyncSuccess(:final summary, :final simulateOffline, :final lastSyncedAt):
        emit(
          SyncSuccess(
            summary: summary,
            pendingCount: event.pendingCount,
            simulateOffline: simulateOffline,
            lastSyncedAt: lastSyncedAt,
          ),
        );
      case SyncFailureState(:final message, :final simulateOffline, :final lastSyncedAt):
        emit(
          SyncFailureState(
            message: message,
            pendingCount: event.pendingCount,
            simulateOffline: simulateOffline,
            lastSyncedAt: lastSyncedAt,
          ),
        );
    }
  }

  void _onSimulateOfflineToggled(
    SimulateOfflineToggled event,
    Emitter<SyncState> emit,
  ) {
    emit(
      SyncIdle(
        pendingCount: state.pendingCount,
        simulateOffline: event.enabled,
        lastSyncedAt: state.lastSyncedAt,
      ),
    );
    if (!event.enabled && state.pendingCount > 0) {
      add(const SyncRequested());
    }
  }

  Future<void> _onSyncRequested(
    SyncRequested event,
    Emitter<SyncState> emit,
  ) async {
    final session = _authRepository.currentSession;
    if (session is SessionUnauthenticated) {
      return;
    }

    emit(
      SyncInProgress(
        pendingCount: state.pendingCount,
        simulateOffline: state.simulateOffline,
        lastSyncedAt: state.lastSyncedAt,
      ),
    );

    final result = await _syncRepository.synchronize(
      userId: session.userId,
      simulateOffline: state.simulateOffline,
      isGuestMode: session.isGuest,
    );

    result.fold(
      onSuccess: (summary) {
        final remaining = math.max(0, state.pendingCount - summary.pushedCount);
        emit(
          SyncSuccess(
            summary: summary,
            pendingCount: remaining,
            simulateOffline: state.simulateOffline,
            lastSyncedAt: summary.syncedAt,
          ),
        );
      },
      onFailure: (failure) {
        emit(
          SyncFailureState(
            message: failure.message,
            pendingCount: state.pendingCount,
            simulateOffline: state.simulateOffline,
            lastSyncedAt: state.lastSyncedAt,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _pendingSub?.cancel();
    await _connectivitySub?.cancel();
    return super.close();
  }
}

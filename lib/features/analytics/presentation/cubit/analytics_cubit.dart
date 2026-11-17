import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/core/time/clock.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_models.dart';
import 'package:ledgerflow_flutter/features/analytics/domain/analytics_repository.dart';

sealed class AnalyticsState extends Equatable {
  const AnalyticsState(this.month);

  final DateTime month;

  @override
  List<Object?> get props => [month];
}

final class AnalyticsLoading extends AnalyticsState {
  const AnalyticsLoading(super.month);
}

final class AnalyticsLoaded extends AnalyticsState {
  const AnalyticsLoaded(this.snapshot) : super(const _MonthSentinel());

  @override
  DateTime get month => snapshot.summary.month;

  final MonthlyAnalyticsSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

final class AnalyticsEmpty extends AnalyticsState {
  const AnalyticsEmpty(super.month);
}

final class AnalyticsError extends AnalyticsState {
  const AnalyticsError(super.month, this.message);

  final String message;

  @override
  List<Object?> get props => [month, message];
}

class _MonthSentinel implements DateTime {
  const _MonthSentinel();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.utc(1970);
}

class AnalyticsCubit extends Cubit<AnalyticsState> {
  AnalyticsCubit({
    required AnalyticsRepository repository,
    required AppClock clock,
  })  : _repository = repository,
        _selectedMonth = _normalizeMonth(clock.nowUtc()),
        super(AnalyticsLoading(_normalizeMonth(clock.nowUtc()))) {
    _subscribe(_selectedMonth);
  }

  final AnalyticsRepository _repository;
  DateTime _selectedMonth;
  StreamSubscription<MonthlyAnalyticsSnapshot>? _subscription;

  static DateTime _normalizeMonth(DateTime date) =>
      DateTime.utc(date.year, date.month, 1);

  void selectMonth(DateTime month) {
    final normalized = _normalizeMonth(month);
    if (normalized == _selectedMonth && state is! AnalyticsError) {
      return;
    }
    _selectedMonth = normalized;
    _subscribe(_selectedMonth);
  }

  void previousMonth() {
    selectMonth(DateTime.utc(_selectedMonth.year, _selectedMonth.month - 1, 1));
  }

  void nextMonth() {
    selectMonth(DateTime.utc(_selectedMonth.year, _selectedMonth.month + 1, 1));
  }

  void retry() {
    _subscribe(_selectedMonth);
  }

  void _subscribe(DateTime month) {
    emit(AnalyticsLoading(month));
    _subscription?.cancel();
    _subscription = _repository.watchMonthlyAnalytics(month).listen(
      (snapshot) {
        if (snapshot.isEmpty) {
          emit(AnalyticsEmpty(month));
        } else {
          emit(AnalyticsLoaded(snapshot));
        }
      },
      onError: (Object error, StackTrace _) {
        emit(AnalyticsError(month, error.toString()));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

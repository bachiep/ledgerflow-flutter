import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class TransactionSearchEvent extends Equatable {
  const TransactionSearchEvent();

  @override
  List<Object?> get props => [];
}

final class SearchQueryChanged extends TransactionSearchEvent {
  const SearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class SearchCleared extends TransactionSearchEvent {
  const SearchCleared();
}

/// Debounces search input and cancels superseded queries via [restartable].
class TransactionSearchBloc extends Bloc<TransactionSearchEvent, String> {
  TransactionSearchBloc({
    Duration debounceDuration = const Duration(milliseconds: 300),
  })  : _debounceDuration = debounceDuration,
        super('') {
    on<SearchQueryChanged>(_onQueryChanged, transformer: restartable());
    on<SearchCleared>(_onCleared, transformer: restartable());
  }

  final Duration _debounceDuration;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<String> emit,
  ) async {
    final normalized = event.query.trim();
    if (normalized.isEmpty) {
      emit('');
      return;
    }

    await Future<void>.delayed(_debounceDuration);
    if (!emit.isDone) {
      emit(normalized);
    }
  }

  void _onCleared(
    SearchCleared event,
    Emitter<String> emit,
  ) {
    emit('');
  }
}

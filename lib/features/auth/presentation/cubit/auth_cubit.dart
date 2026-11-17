import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/auth/domain/auth_repository.dart';

class AuthState extends Equatable {
  const AuthState({
    required this.session,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AppSession session;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState copyWith({
    AppSession? session,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      session: session ?? this.session,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [session, isSubmitting, errorMessage];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository)
      : super(AuthState(session: _repository.currentSession)) {
    _sub = _repository.watchSession().listen((session) {
      emit(state.copyWith(session: session, isSubmitting: false, clearError: true));
    });
  }

  final AuthRepository _repository;
  StreamSubscription<AppSession>? _sub;

  bool get isSupabaseConfigured => _repository.isSupabaseConfigured;

  Future<void> enterGuestMode() async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await _repository.enterGuestMode();
    result.fold(
      onSuccess: (session) => emit(
        state.copyWith(session: session, isSubmitting: false, clearError: true),
      ),
      onFailure: (failure) => emit(
        state.copyWith(isSubmitting: false, errorMessage: failure.message),
      ),
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await _repository.signInWithSupabase(
      email: email,
      password: password,
    );
    result.fold(
      onSuccess: (session) => emit(
        state.copyWith(session: session, isSubmitting: false, clearError: true),
      ),
      onFailure: (failure) => emit(
        state.copyWith(isSubmitting: false, errorMessage: failure.message),
      ),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await _repository.signUpWithSupabase(
      email: email,
      password: password,
    );
    result.fold(
      onSuccess: (session) => emit(
        state.copyWith(session: session, isSubmitting: false, clearError: true),
      ),
      onFailure: (failure) => emit(
        state.copyWith(isSubmitting: false, errorMessage: failure.message),
      ),
    );
  }

  Future<void> signOut() async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await _repository.signOut();
    result.fold(
      onSuccess: (_) => emit(
        const AuthState(session: SessionUnauthenticated()),
      ),
      onFailure: (failure) => emit(
        state.copyWith(isSubmitting: false, errorMessage: failure.message),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

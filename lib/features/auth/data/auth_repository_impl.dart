import 'dart:async';

import 'package:ledgerflow_flutter/core/database/sample_data_seeder.dart';
import 'package:ledgerflow_flutter/core/error/failure.dart';
import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';
import 'package:ledgerflow_flutter/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required SampleDataSeeder seeder,
    SupabaseClient? supabaseClient,
    AppSession initialSession = const SessionUnauthenticated(),
  })  : _seeder = seeder,
        _supabase = supabaseClient,
        _currentSession = _resolveInitialSession(supabaseClient, initialSession);

  final SampleDataSeeder _seeder;
  final SupabaseClient? _supabase;
  final StreamController<AppSession> _controller =
      StreamController<AppSession>.broadcast();
  AppSession _currentSession;

  static AppSession _resolveInitialSession(
    SupabaseClient? client,
    AppSession fallback,
  ) {
    final user = client?.auth.currentUser;
    if (user != null) {
      return SessionSupabaseUser(uid: user.id, email: user.email ?? '');
    }
    return fallback;
  }

  @override
  AppSession get currentSession => _currentSession;

  @override
  bool get isSupabaseConfigured => _supabase != null;

  @override
  Stream<AppSession> watchSession() => _controller.stream;

  void _setSession(AppSession session) {
    _currentSession = session;
    if (!_controller.isClosed) {
      _controller.add(session);
    }
  }

  @override
  Future<Result<AppSession>> enterGuestMode() async {
    try {
      await _seeder.seedGuestSampleIfEmpty();
      const guest = SessionGuest();
      _setSession(guest);
      return const Success(guest);
    } catch (error) {
      return Err(DatabaseFailure('Failed to initialize guest ledger.', cause: error));
    }
  }

  @override
  Future<Result<AppSession>> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    final client = _supabase;
    if (client == null) {
      return const Err(
        AuthFailure(
          'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
        ),
      );
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const Err(AuthFailure('Sign in succeeded without user profile.'));
      }
      await _seeder.seedDefaultCategories();
      final session = SessionSupabaseUser(
        uid: user.id,
        email: user.email ?? email.trim(),
      );
      _setSession(session);
      return Success(session);
    } on AuthException catch (error) {
      return Err(AuthFailure(error.message, cause: error));
    } catch (error) {
      return Err(NetworkFailure('Failed to reach Supabase Auth.', cause: error));
    }
  }

  @override
  Future<Result<AppSession>> signUpWithSupabase({
    required String email,
    required String password,
  }) async {
    final client = _supabase;
    if (client == null) {
      return const Err(
        AuthFailure(
          'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
        ),
      );
    }
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const Err(AuthFailure('Check your inbox to verify your account.'));
      }
      await _seeder.seedDefaultCategories();
      final session = SessionSupabaseUser(
        uid: user.id,
        email: user.email ?? email.trim(),
      );
      _setSession(session);
      return Success(session);
    } on AuthException catch (error) {
      return Err(AuthFailure(error.message, cause: error));
    } catch (error) {
      return Err(NetworkFailure('Failed to reach Supabase Auth.', cause: error));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      final client = _supabase;
      if (client != null && _currentSession.isCloudUser) {
        await client.auth.signOut();
      }
      _setSession(const SessionUnauthenticated());
      return const Success(null);
    } catch (error) {
      return Err(AuthFailure('Sign out failed.', cause: error));
    }
  }

  Future<void> dispose() => _controller.close();
}

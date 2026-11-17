import 'package:ledgerflow_flutter/core/result/result.dart';
import 'package:ledgerflow_flutter/features/auth/domain/app_session.dart';

abstract interface class AuthRepository {
  AppSession get currentSession;
  Stream<AppSession> watchSession();
  bool get isSupabaseConfigured;

  Future<Result<AppSession>> enterGuestMode();

  Future<Result<AppSession>> signInWithSupabase({
    required String email,
    required String password,
  });

  Future<Result<AppSession>> signUpWithSupabase({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();
}

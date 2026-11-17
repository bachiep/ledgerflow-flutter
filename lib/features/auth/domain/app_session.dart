import 'package:equatable/equatable.dart';

sealed class AppSession extends Equatable {
  const AppSession();

  String get userId;
  bool get isAuthenticated => this is! SessionUnauthenticated;
  bool get isGuest => this is SessionGuest;
  bool get isCloudUser => this is SessionSupabaseUser;

  @override
  List<Object?> get props => [];
}

final class SessionUnauthenticated extends AppSession {
  const SessionUnauthenticated();

  @override
  String get userId => '';
}

final class SessionGuest extends AppSession {
  const SessionGuest({this.guestId = 'guest-local'});

  final String guestId;

  @override
  String get userId => guestId;

  @override
  List<Object?> get props => [guestId];
}

final class SessionSupabaseUser extends AppSession {
  const SessionSupabaseUser({
    required this.uid,
    required this.email,
  });

  final String uid;
  final String email;

  @override
  String get userId => uid;

  @override
  List<Object?> get props => [uid, email];
}

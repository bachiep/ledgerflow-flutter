import 'package:equatable/equatable.dart';

/// Typed failure hierarchy mapped across data and domain boundaries.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  List<Object?> get props => [message, cause];
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.cause});
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});
}

final class SyncFailure extends Failure {
  const SyncFailure(super.message, {super.cause});
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}

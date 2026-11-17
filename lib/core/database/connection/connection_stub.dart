import 'package:drift/drift.dart';

QueryExecutor openAppConnection() {
  throw UnsupportedError(
    'SQLite native connection is unavailable on this platform without a custom executor.',
  );
}

/// Injectable clock abstraction for deterministic time handling in sync and tests.
abstract interface class AppClock {
  DateTime nowUtc();
}

final class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

final class FixedClock implements AppClock {
  FixedClock(DateTime initialUtc) : _current = initialUtc.toUtc();

  DateTime _current;

  @override
  DateTime nowUtc() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  void setNow(DateTime utc) {
    _current = utc.toUtc();
  }
}

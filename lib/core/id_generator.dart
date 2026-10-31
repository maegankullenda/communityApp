abstract interface class IdGenerator {
  String next(String prefix);
}

final class SequentialIdGenerator implements IdGenerator {
  int _sequence = 0;

  @override
  String next(String prefix) {
    _sequence += 1;
    return '$prefix-$_sequence';
  }
}

final class TimeBasedIdGenerator implements IdGenerator {
  int _sequence = 0;

  @override
  String next(String prefix) {
    _sequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }
}

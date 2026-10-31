/// Appointment times are local wall-clock values, such as 09:00 on a given
/// day. They are stored and sent as fixed-width text so a database time zone
/// cannot move them.
String wallClockIso(DateTime value) {
  final clock = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
  );
  String two(int number) => number.toString().padLeft(2, '0');
  final year = clock.year.toString().padLeft(4, '0');
  final milliseconds = clock.millisecond.toString().padLeft(3, '0');
  return '$year-${two(clock.month)}-${two(clock.day)}'
      'T${two(clock.hour)}:${two(clock.minute)}:${two(clock.second)}'
      '.$milliseconds';
}

String normalizeWallClock(String value) => wallClockIso(DateTime.parse(value));

import 'package:community_app/features/profile/domain/car_wash_pricing.dart';

const carWashOpeningHours = [8, 9, 10, 11, 12, 13, 14, 15, 16];

const appointmentOpeningHours = [9, 11, 13, 15];

const offeringHourChoices = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, //
  12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
];

/// Monday is 1 and Sunday is 7, matching [DateTime.weekday].
const openDayChoices = <(int, String)>[
  (1, 'Mon'),
  (2, 'Tue'),
  (3, 'Wed'),
  (4, 'Thu'),
  (5, 'Fri'),
  (6, 'Sat'),
  (7, 'Sun'),
];

const weekdays = [1, 2, 3, 4, 5];

const weekendDays = [6, 7];

/// Hours that apply on [weekday].
///
/// When both specific lists are empty, [sharedHours] is used for every day.
/// That keeps offerings saved before weekday and weekend hours were separate.
List<int> hoursOnDay({
  required int weekday,
  required List<int> weekdayHours,
  required List<int> weekendHours,
  List<int> sharedHours = const [],
}) {
  if (weekdayHours.isEmpty && weekendHours.isEmpty) {
    return sharedHours;
  }
  return weekendDays.contains(weekday) ? weekendHours : weekdayHours;
}

/// Sorted hours, or null when an hour is outside 00:00–23:00.
List<int>? checkedOpeningHours(List<int> raw) {
  final hours = <int>{};
  for (final hour in raw) {
    if (!offeringHourChoices.contains(hour)) {
      return null;
    }
    hours.add(hour);
  }
  return hours.toList()..sort();
}

/// Weekday and weekend hours for one offering.
///
/// A single [openHours] list is applied to both parts of the week. That is
/// how offerings were saved before the two lists existed.
({List<int> weekdayHours, List<int> weekendHours})? splitOpeningHours({
  required List<int> openHours,
  required List<int> weekdayHours,
  required List<int> weekendHours,
  required List<int> openWeekdays,
}) {
  final coversWeekday =
      openWeekdays.isEmpty || openWeekdays.any(weekdays.contains);
  final coversWeekend =
      openWeekdays.isEmpty || openWeekdays.any(weekendDays.contains);
  if (weekdayHours.isEmpty && weekendHours.isEmpty) {
    final shared = checkedOpeningHours(openHours);
    if (shared == null || shared.isEmpty) {
      return null;
    }
    return (weekdayHours: shared, weekendHours: shared);
  }
  final weekdayChecked = checkedOpeningHours(weekdayHours);
  final weekendChecked = checkedOpeningHours(weekendHours);
  if (weekdayChecked == null || weekendChecked == null) {
    return null;
  }
  if (coversWeekday && weekdayChecked.isEmpty) {
    return null;
  }
  if (coversWeekend && weekendChecked.isEmpty) {
    return null;
  }
  return (weekdayHours: weekdayChecked, weekendHours: weekendChecked);
}

String formatOpeningHours(List<int> hours) {
  return hours
      .map((hour) => '${hour.toString().padLeft(2, '0')}:00')
      .join(', ');
}

const everyDay = [1, 2, 3, 4, 5, 6, 7];

String openingSlotId({
  required String serviceId,
  required String providerId,
  required DateTime start,
}) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '$serviceId-$providerId-${start.year}${two(start.month)}${two(start.day)}'
      '-${two(start.hour)}${two(start.minute)}';
}

List<int> openingHoursFor(String serviceId) {
  return serviceId == carWashServiceId
      ? carWashOpeningHours
      : appointmentOpeningHours;
}

/// How far ahead a booking may start, and how long the bookable period lasts.
enum AdvanceUnit { hour, day, week, month, nextWeek }

AdvanceUnit advanceUnitFromName(String? name) {
  for (final unit in AdvanceUnit.values) {
    if (unit.name == name) {
      return unit;
    }
  }
  return AdvanceUnit.hour;
}

/// Default is the next available hour, open for one week.
final class BookingWindow {
  const BookingWindow({
    this.advanceAmount = 0,
    this.advanceUnit = AdvanceUnit.hour,
    this.openForAmount = 1,
    this.openForUnit = AdvanceUnit.week,
  });

  final int advanceAmount;
  final AdvanceUnit advanceUnit;

  /// How long customers can book after the window opens.
  final int openForAmount;
  final AdvanceUnit openForUnit;
}

final class BookingRange {
  const BookingRange({required this.earliest, required this.until});

  /// First instant that can be booked.
  final DateTime earliest;

  /// First instant that is too late to book.
  final DateTime until;
}

DateTime _calendarDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// The Monday after this week. A Monday starts the following Monday.
DateTime nextCalendarWeek(DateTime day) {
  final today = _calendarDay(day);
  final untilMonday = (DateTime.monday - today.weekday + 7) % 7;
  return today.add(Duration(days: untilMonday == 0 ? 7 : untilMonday));
}

BookingRange bookingRange(
  DateTime now, [
  BookingWindow window = const BookingWindow(),
]) {
  final today = _calendarDay(now);
  final earliest = switch (window.advanceUnit) {
    AdvanceUnit.hour => now.add(Duration(hours: window.advanceAmount)),
    AdvanceUnit.day => today.add(Duration(days: window.advanceAmount)),
    AdvanceUnit.week => today.add(Duration(days: 7 * window.advanceAmount)),
    AdvanceUnit.month => DateTime(
      today.year,
      today.month + window.advanceAmount,
      today.day,
    ),
    AdvanceUnit.nextWeek => nextCalendarWeek(today),
  };
  final startDay = _calendarDay(earliest);
  final until = switch (window.openForUnit) {
    AdvanceUnit.hour => earliest.add(Duration(hours: window.openForAmount)),
    AdvanceUnit.day => startDay.add(Duration(days: window.openForAmount)),
    AdvanceUnit.week => startDay.add(Duration(days: 7 * window.openForAmount)),
    AdvanceUnit.month => DateTime(
      startDay.year,
      startDay.month + window.openForAmount,
      startDay.day,
    ),
    AdvanceUnit.nextWeek => startDay.add(const Duration(days: 7)),
  };
  return BookingRange(earliest: earliest, until: until);
}

/// Calendar days that overlap [window]. At most a year of days are returned.
List<DateTime> bookingDays(
  DateTime now, [
  BookingWindow window = const BookingWindow(),
]) {
  final range = bookingRange(now, window);
  var day = _calendarDay(range.earliest);
  final lastInstant = range.until.subtract(const Duration(microseconds: 1));
  final last = _calendarDay(lastInstant);
  if (last.isBefore(day)) {
    return const [];
  }
  final days = <DateTime>[];
  while (!day.isAfter(last) && days.length < 366) {
    days.add(day);
    day = day.add(const Duration(days: 1));
  }
  return days;
}

/// A window customers can actually book inside, and no longer than a year.
bool bookingWindowIsValid(BookingWindow window) {
  if (window.advanceAmount < 0 || window.openForAmount < 1) {
    return false;
  }
  if (window.openForUnit == AdvanceUnit.hour ||
      window.openForUnit == AdvanceUnit.nextWeek) {
    return false;
  }
  if (window.advanceUnit == AdvanceUnit.hour &&
      window.advanceAmount > 24 * 30) {
    return false;
  }
  return bookingDays(DateTime(2026, 1, 1), window).length <= 366 &&
      bookingDays(DateTime(2026, 1, 1), window).isNotEmpty;
}

/// True when [start] is inside the provider's booking window.
///
/// A notice of zero hours keeps the next hour after [now]. Any longer notice
/// includes a slot that starts exactly when the window opens.
bool isWithinBookingWindow(
  DateTime start,
  DateTime now, [
  BookingWindow window = const BookingWindow(),
]) {
  final range = bookingRange(now, window);
  final opened =
      window.advanceUnit == AdvanceUnit.hour && window.advanceAmount == 0
      ? start.isAfter(now)
      : !start.isBefore(range.earliest);
  return opened && start.isBefore(range.until);
}

/// Days in the booking window that fall on [openWeekdays].
/// An empty list means every day in that window.
List<DateTime> scheduledDays(
  DateTime now,
  List<int> openWeekdays, {
  BookingWindow window = const BookingWindow(),
}) {
  final allowed = openWeekdays.isEmpty ? everyDay : openWeekdays;
  return [
    for (final day in bookingDays(now, window))
      if (allowed.contains(day.weekday)) day,
  ];
}

/// Today and the rest of the default booking week.
List<DateTime> openingDays(DateTime now) {
  return bookingDays(now);
}

/// Days a customer can order, using the provider's booking window.
List<DateTime> menuDays(
  DateTime now, [
  BookingWindow window = const BookingWindow(),
]) {
  return bookingDays(now, window);
}

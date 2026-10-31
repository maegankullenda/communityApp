import 'package:community_app/features/scheduling/domain/opening_hours.dart';

final class ServiceOffering {
  const ServiceOffering({
    required this.providerId,
    required this.serviceId,
    required this.name,
    required this.description,
    required this.openHours,
    this.weekdayHours = const [],
    this.weekendHours = const [],
    this.openWeekdays = const [],
    this.advanceAmount = 0,
    this.advanceUnit = AdvanceUnit.hour,
    this.openForAmount = 1,
    this.openForUnit = AdvanceUnit.week,
    this.autoConfirm = true,
    this.concurrentBookings = 1,
  });

  final String providerId;
  final String serviceId;
  final String name;
  final String description;

  /// Combined hours kept for offerings saved before weekday and weekend
  /// times were stored separately.
  final List<int> openHours;
  final List<int> weekdayHours;
  final List<int> weekendHours;

  /// Monday is 1 and Sunday is 7. Empty means every day.
  final List<int> openWeekdays;

  /// How long before a visit this provider starts taking bookings.
  /// Zero hours means the next available hour.
  final int advanceAmount;
  final AdvanceUnit advanceUnit;

  /// How long customers can book after bookings open.
  final int openForAmount;
  final AdvanceUnit openForUnit;

  /// When this is off, a new booking stays pending until the provider confirms it.
  final bool autoConfirm;

  /// How many customers can book the same time.
  final int concurrentBookings;

  BookingWindow get bookingWindow {
    return BookingWindow(
      advanceAmount: advanceAmount,
      advanceUnit: advanceUnit,
      openForAmount: openForAmount,
      openForUnit: openForUnit,
    );
  }

  List<int> hoursOn(int weekday) {
    return hoursOnDay(
      weekday: weekday,
      weekdayHours: weekdayHours,
      weekendHours: weekendHours,
      sharedHours: openHours,
    );
  }

  /// Whether customers may book [start]. Closed days and hours stay closed
  /// even when an older slot row is still stored.
  bool isOpenAt(DateTime start) {
    if (openWeekdays.isNotEmpty && !openWeekdays.contains(start.weekday)) {
      return false;
    }
    return hoursOn(start.weekday).contains(start.hour);
  }
}

String offeringKey(String providerId, String serviceId) {
  return '$providerId|$serviceId';
}

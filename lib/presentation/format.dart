import 'package:community_app/features/scheduling/domain/appointment.dart';

String formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatDay(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[value.weekday - 1];
  final month = months[value.month - 1];
  return '$weekday ${value.day} $month';
}

String formatMonth(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String formatAppointmentWhen(DateTime start) {
  return '${formatDay(start)} at ${formatTime(start)}';
}

String formatIsoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String formatSuggestedRange(DateTime from, DateTime until) {
  return '${formatDay(from)} to ${formatDay(until)}';
}

String formatRand(int cents) => 'R${formatPrice(cents)}';

String formatHours(int hours) => hours == 1 ? '1 hour' : '$hours hours';

String formatPrice(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final major = absolute ~/ 100;
  final minor = (absolute % 100).toString().padLeft(2, '0');
  final rendered = '$major.$minor';
  return negative ? '-$rendered' : rendered;
}

String bookingConfirmationLabel(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.booked => 'Confirmed',
    AppointmentStatus.pending => 'Pending confirmation',
    AppointmentStatus.declined => 'Declined',
    AppointmentStatus.cancelled => 'Cancelled',
  };
}

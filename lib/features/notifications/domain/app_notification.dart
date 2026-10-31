enum BookingNoticeKind { requested, confirmed, declined }

final class AppNotification {
  const AppNotification({
    required this.id,
    required this.accountId,
    required this.appointmentId,
    required this.kind,
    required this.message,
    required this.createdAt,
    this.visibleUntil,
    this.read = false,
  });

  final String id;
  final String accountId;
  final String appointmentId;
  final BookingNoticeKind kind;
  final String message;
  final DateTime createdAt;

  /// Customer notices stay until this appointment time, then they are removed.
  final DateTime? visibleUntil;
  final bool read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      accountId: accountId,
      appointmentId: appointmentId,
      kind: kind,
      message: message,
      createdAt: createdAt,
      visibleUntil: visibleUntil,
      read: read ?? this.read,
    );
  }
}

String bookingRequestedMessage({
  required String customerName,
  required String serviceName,
}) {
  return 'New Booking: $customerName has requested a $serviceName.';
}

String bookingConfirmedMessage({
  required String providerName,
  required String serviceName,
  required String when,
}) {
  return 'Booking Confirmed: $providerName has confirmed your $serviceName appointment for $when';
}

String noticeWhen(DateTime start) {
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
  final hour = start.hour.toString().padLeft(2, '0');
  final minute = start.minute.toString().padLeft(2, '0');
  final weekday = weekdays[start.weekday - 1];
  final month = months[start.month - 1];
  return '$weekday ${start.day} $month at $hour:$minute';
}

String bookingDeclinedMessage({
  required String providerName,
  required String serviceName,
}) {
  return 'Booking declined: $providerName declined your $serviceName.';
}

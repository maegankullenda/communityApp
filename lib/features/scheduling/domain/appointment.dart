enum AppointmentStatus { booked, pending, declined, cancelled }

final class Appointment {
  const Appointment({
    required this.id,
    required this.userId,
    required this.slotId,
    required this.providerId,
    required this.serviceId,
    required this.start,
    required this.duration,
    required this.status,
    this.vehicleLabel,
    this.priceCents,
    this.vehicleIds = const [],
    this.washId,
    this.washName,
    this.vehicleWashes = const {},
    this.declineMessage = '',
    this.suggestedFrom,
    this.suggestedUntil,
  });

  final String id;
  final String userId;
  final String slotId;
  final String providerId;
  final String serviceId;
  final DateTime start;
  final Duration duration;
  final AppointmentStatus status;
  final String? vehicleLabel;
  final int? priceCents;
  final List<String> vehicleIds;
  final String? washId;
  final String? washName;

  /// Wash chosen for each vehicle. Empty on older bookings that stored one wash.
  final Map<String, String> vehicleWashes;

  /// Why the provider declined this time, with a suggested date range.
  final String declineMessage;
  final DateTime? suggestedFrom;
  final DateTime? suggestedUntil;

  bool get isActive =>
      status == AppointmentStatus.booked || status == AppointmentStatus.pending;

  bool get isConfirmed => status == AppointmentStatus.booked;

  bool get isListedForCustomer =>
      isActive || status == AppointmentStatus.declined;

  /// Booked, pending, and declined visits the customer can still change.
  bool get canCustomerChange => isListedForCustomer;

  /// The wash for each vehicle, including bookings saved before per-vehicle washes.
  Map<String, String> washesForVehicles() {
    if (vehicleWashes.isNotEmpty) {
      return vehicleWashes;
    }
    final id = washId;
    if (id == null || id.isEmpty) {
      return const {};
    }
    return {for (final vehicleId in vehicleIds) vehicleId: id};
  }
}

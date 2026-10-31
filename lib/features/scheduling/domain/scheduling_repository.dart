import 'package:community_app/core/result.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

enum BookingFailure {
  slotNotFound,
  slotInThePast,
  outsideBookingWindow,
  notOpen,
  slotFull,
  alreadyBooked,
  serviceMismatch,
  vehicleRequired,
  unknownVehicle,
  appointmentNotFound,
  washRequired,
  unknownWash,
  treatmentRequired,
  unknownTreatment,
  serviceUnavailable,
  missingDeclineMessage,
  invalidSuggestedRange,
}

abstract interface class SchedulingRepository {
  Future<TimeSlot?> findSlot(String id);

  Future<List<TimeSlot>> slotsFor({
    required String serviceId,
    String? providerId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<Appointment?> activeAppointmentFor({
    required String userId,
    required String slotId,
  });

  Future<Appointment?> findAppointment(String id);

  /// Reserves one place on the slot and stores the appointment.
  /// Capacity is checked again here so two bookings cannot both succeed.
  Future<Result<Appointment, BookingFailure>> tryReserve({
    required String appointmentId,
    required String userId,
    required String slotId,
    String? vehicleLabel,
    int? priceCents,
    List<String> vehicleIds = const [],
    Duration? duration,
    String? washId,
    String? washName,
    Map<String, String> vehicleWashes = const {},
    AppointmentStatus status = AppointmentStatus.booked,
  });

  /// Moves a booking the customer can still change onto [slotId], or updates
  /// its vehicle or wash on the same time. A declined booking does not hold
  /// its old time, so that time is reserved again. [status] replaces the
  /// current status when the customer is revising a decline.
  Future<Result<Appointment, BookingFailure>> reschedule({
    required String appointmentId,
    required String userId,
    required String slotId,
    String? vehicleLabel,
    int? priceCents,
    List<String> vehicleIds = const [],
    Duration? duration,
    String? washId,
    String? washName,
    Map<String, String> vehicleWashes = const {},
    AppointmentStatus? status,
  });

  /// Marks the booking cancelled. An active booking opens its time again.
  Future<Result<Appointment, BookingFailure>> cancelAppointment({
    required String appointmentId,
    required String userId,
  });

  /// Moves a pending booking to confirmed without changing the reserved time.
  Future<Result<Appointment, BookingFailure>> confirmAppointment({
    required String appointmentId,
    required String providerId,
  });

  /// Declines a pending booking, frees the time, and stores the provider's note.
  /// A suggested date range is optional.
  Future<Result<Appointment, BookingFailure>> declineAppointment({
    required String appointmentId,
    required String providerId,
    required String message,
    DateTime? suggestedFrom,
    DateTime? suggestedUntil,
  });

  Future<List<Appointment>> appointmentsForUser(String userId);

  Future<List<Appointment>> appointmentsForProvider(String providerId);

  Future<void> publishSlot(TimeSlot slot);

  /// Drops an opening that nobody has booked.
  Future<void> removeSlot(String id);
}

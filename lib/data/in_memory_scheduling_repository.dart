import 'package:community_app/core/result.dart';
import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/slot_coverage.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

final class InMemorySchedulingRepository implements SchedulingRepository {
  InMemorySchedulingRepository(this._store);

  final CommunityStore _store;

  @override
  Future<TimeSlot?> findSlot(String id) async => _store.slots[id];

  @override
  Future<List<TimeSlot>> slotsFor({
    required String serviceId,
    String? providerId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final slots = _store.slots.values.where((slot) {
      final matchesProvider =
          providerId == null || slot.providerId == providerId;
      final startsInRange =
          !slot.start.isBefore(rangeStart) && slot.start.isBefore(rangeEnd);
      return slot.serviceId == serviceId && matchesProvider && startsInRange;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
    return slots;
  }

  @override
  Future<Appointment?> activeAppointmentFor({
    required String userId,
    required String slotId,
  }) async {
    for (final appointment in _store.appointments.values) {
      if (appointment.userId == userId &&
          appointment.slotId == slotId &&
          appointment.isActive) {
        return appointment;
      }
    }
    return null;
  }

  @override
  Future<Appointment?> findAppointment(String id) async =>
      _store.appointments[id];

  @override
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
  }) async {
    final slot = _store.slots[slotId];
    if (slot == null) {
      return const Err(BookingFailure.slotNotFound);
    }
    final bookedFor = duration ?? slot.duration;
    final covered = _covered(slot, bookedFor);
    if (covered.isEmpty) {
      return const Err(BookingFailure.slotNotFound);
    }
    if (covered.any((item) => !item.hasCapacity)) {
      return const Err(BookingFailure.slotFull);
    }
    for (final item in covered) {
      _store.slots[item.id] = item.reserveOne();
    }
    final appointment = Appointment(
      id: appointmentId,
      userId: userId,
      slotId: slotId,
      providerId: slot.providerId,
      serviceId: slot.serviceId,
      start: slot.start,
      duration: bookedFor,
      status: status,
      vehicleLabel: vehicleLabel,
      priceCents: priceCents,
      vehicleIds: vehicleIds,
      washId: washId,
      washName: washName,
      vehicleWashes: vehicleWashes,
    );
    _store.appointments[appointment.id] = appointment;
    return Success(appointment);
  }

  @override
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
  }) async {
    final current = _store.appointments[appointmentId];
    if (current == null ||
        current.userId != userId ||
        !current.canCustomerChange) {
      return const Err(BookingFailure.appointmentNotFound);
    }
    final slot = _store.slots[slotId];
    if (slot == null) {
      return const Err(BookingFailure.slotNotFound);
    }
    if (slot.serviceId != current.serviceId ||
        slot.providerId != current.providerId) {
      return const Err(BookingFailure.serviceMismatch);
    }
    if (slot.id != current.slotId) {
      final clash = await activeAppointmentFor(userId: userId, slotId: slot.id);
      if (clash != null) {
        return const Err(BookingFailure.alreadyBooked);
      }
    }
    final bookedFor = duration ?? slot.duration;
    final revisingDeclined = current.status == AppointmentStatus.declined;
    final oldIds = revisingDeclined
        ? <String>{}
        : {for (final item in _coveredAppointment(current)) item.id};
    final fresh = _covered(slot, bookedFor);
    if (fresh.isEmpty) {
      return const Err(BookingFailure.slotNotFound);
    }
    if (fresh.any((item) => !oldIds.contains(item.id) && !item.hasCapacity)) {
      return const Err(BookingFailure.slotFull);
    }
    for (final item in _coveredAppointment(current)) {
      if (fresh.any((next) => next.id == item.id)) {
        continue;
      }
      final latest = _store.slots[item.id];
      if (latest != null && latest.bookedCount > 0) {
        _store.slots[item.id] = latest.releaseOne();
      }
    }
    for (final item in fresh) {
      if (oldIds.contains(item.id)) {
        continue;
      }
      _store.slots[item.id] = item.reserveOne();
    }
    final updated = Appointment(
      id: current.id,
      userId: current.userId,
      slotId: slot.id,
      providerId: slot.providerId,
      serviceId: slot.serviceId,
      start: slot.start,
      duration: bookedFor,
      status: status ?? current.status,
      vehicleLabel: vehicleLabel,
      priceCents: priceCents,
      vehicleIds: vehicleIds,
      washId: washId,
      washName: washName,
      vehicleWashes: vehicleWashes,
      declineMessage: revisingDeclined ? '' : current.declineMessage,
      suggestedFrom: revisingDeclined ? null : current.suggestedFrom,
      suggestedUntil: revisingDeclined ? null : current.suggestedUntil,
    );
    _store.appointments[updated.id] = updated;
    return Success(updated);
  }

  @override
  Future<Result<Appointment, BookingFailure>> confirmAppointment({
    required String appointmentId,
    required String providerId,
  }) async {
    final current = _store.appointments[appointmentId];
    if (current == null ||
        current.providerId != providerId ||
        current.status != AppointmentStatus.pending) {
      return const Err(BookingFailure.appointmentNotFound);
    }
    final confirmed = Appointment(
      id: current.id,
      userId: current.userId,
      slotId: current.slotId,
      providerId: current.providerId,
      serviceId: current.serviceId,
      start: current.start,
      duration: current.duration,
      status: AppointmentStatus.booked,
      vehicleLabel: current.vehicleLabel,
      priceCents: current.priceCents,
      vehicleIds: current.vehicleIds,
      washId: current.washId,
      washName: current.washName,
      vehicleWashes: current.vehicleWashes,
    );
    _store.appointments[confirmed.id] = confirmed;
    return Success(confirmed);
  }

  @override
  Future<Result<Appointment, BookingFailure>> declineAppointment({
    required String appointmentId,
    required String providerId,
    required String message,
    DateTime? suggestedFrom,
    DateTime? suggestedUntil,
  }) async {
    final current = _store.appointments[appointmentId];
    if (current == null ||
        current.providerId != providerId ||
        current.status != AppointmentStatus.pending) {
      return const Err(BookingFailure.appointmentNotFound);
    }
    for (final item in _coveredAppointment(current)) {
      final latest = _store.slots[item.id];
      if (latest != null && latest.bookedCount > 0) {
        _store.slots[item.id] = latest.releaseOne();
      }
    }
    final declined = Appointment(
      id: current.id,
      userId: current.userId,
      slotId: current.slotId,
      providerId: current.providerId,
      serviceId: current.serviceId,
      start: current.start,
      duration: current.duration,
      status: AppointmentStatus.declined,
      vehicleLabel: current.vehicleLabel,
      priceCents: current.priceCents,
      vehicleIds: current.vehicleIds,
      washId: current.washId,
      washName: current.washName,
      vehicleWashes: current.vehicleWashes,
      declineMessage: message.trim(),
      suggestedFrom: suggestedFrom == null
          ? null
          : DateTime(
              suggestedFrom.year,
              suggestedFrom.month,
              suggestedFrom.day,
            ),
      suggestedUntil: suggestedUntil == null
          ? null
          : DateTime(
              suggestedUntil.year,
              suggestedUntil.month,
              suggestedUntil.day,
            ),
    );
    _store.appointments[declined.id] = declined;
    return Success(declined);
  }

  @override
  Future<Result<Appointment, BookingFailure>> cancelAppointment({
    required String appointmentId,
    required String userId,
  }) async {
    final current = _store.appointments[appointmentId];
    if (current == null ||
        current.userId != userId ||
        !current.canCustomerChange) {
      return const Err(BookingFailure.appointmentNotFound);
    }
    if (current.status != AppointmentStatus.declined) {
      for (final item in _coveredAppointment(current)) {
        final latest = _store.slots[item.id];
        if (latest != null && latest.bookedCount > 0) {
          _store.slots[item.id] = latest.releaseOne();
        }
      }
    }
    final cancelled = Appointment(
      id: current.id,
      userId: current.userId,
      slotId: current.slotId,
      providerId: current.providerId,
      serviceId: current.serviceId,
      start: current.start,
      duration: current.duration,
      status: AppointmentStatus.cancelled,
      vehicleLabel: current.vehicleLabel,
      priceCents: current.priceCents,
      vehicleIds: current.vehicleIds,
      washId: current.washId,
      washName: current.washName,
      vehicleWashes: current.vehicleWashes,
    );
    _store.appointments[cancelled.id] = cancelled;
    return Success(cancelled);
  }

  @override
  Future<List<Appointment>> appointmentsForUser(String userId) async {
    return _store.appointments.values
        .where((appointment) => appointment.userId == userId)
        .toList();
  }

  @override
  Future<List<Appointment>> appointmentsForProvider(String providerId) async {
    return _store.appointments.values
        .where((appointment) => appointment.providerId == providerId)
        .toList();
  }

  @override
  Future<void> publishSlot(TimeSlot slot) async {
    final current = _store.slots[slot.id];
    _store.slots[slot.id] = TimeSlot(
      id: slot.id,
      providerId: slot.providerId,
      serviceId: slot.serviceId,
      start: slot.start,
      duration: slot.duration,
      capacity: slot.capacity,
      bookedCount: current?.bookedCount ?? slot.bookedCount,
    );
  }

  @override
  Future<void> removeSlot(String id) async {
    final slot = _store.slots[id];
    if (slot == null || slot.bookedCount > 0) {
      return;
    }
    final booked = _store.appointments.values.any(
      (appointment) => appointment.slotId == id && appointment.isActive,
    );
    if (booked) {
      return;
    }
    _store.slots.remove(id);
  }

  List<TimeSlot> _covered(TimeSlot slot, Duration duration) {
    return slotsCoveredBy(
      slots: _store.slots.values,
      providerId: slot.providerId,
      serviceId: slot.serviceId,
      start: slot.start,
      duration: duration,
    );
  }

  List<TimeSlot> _coveredAppointment(Appointment appointment) {
    return slotsCoveredBy(
      slots: _store.slots.values,
      providerId: appointment.providerId,
      serviceId: appointment.serviceId,
      start: appointment.start,
      duration: appointment.duration,
    );
  }
}

import 'package:community_app/core/clock.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/features/notifications/domain/record_booking_notice.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/offerings/domain/wash_repository.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/treatment_quote.dart';
import 'package:community_app/features/scheduling/domain/vehicle_snapshot.dart';
import 'package:community_app/features/scheduling/domain/wash_quote.dart';

final class ChangeAppointment {
  const ChangeAppointment({
    required SchedulingRepository scheduling,
    required ProfileRepository profiles,
    required WashRepository washes,
    required OfferingRepository offerings,
    required Clock clock,
    required RecordBookingNotice notices,
  }) : _scheduling = scheduling,
       _profiles = profiles,
       _washes = washes,
       _offerings = offerings,
       _clock = clock,
       _notices = notices;

  final SchedulingRepository _scheduling;
  final ProfileRepository _profiles;
  final WashRepository _washes;
  final OfferingRepository _offerings;
  final Clock _clock;
  final RecordBookingNotice _notices;

  Future<Result<Appointment, BookingFailure>> call({
    required String userId,
    required String appointmentId,
    required String slotId,
    required String serviceId,
    List<String> vehicleIds = const [],
    String? washId,
    String? treatmentId,
    Map<String, String> vehicleWashes = const {},
  }) async {
    final current = await _scheduling.findAppointment(appointmentId);
    if (current == null ||
        current.userId != userId ||
        !current.canCustomerChange) {
      return const Err(BookingFailure.appointmentNotFound);
    }
    if (current.serviceId != serviceId) {
      return const Err(BookingFailure.serviceMismatch);
    }
    final slot = await _scheduling.findSlot(slotId);
    if (slot == null) {
      return const Err(BookingFailure.slotNotFound);
    }
    if (slot.serviceId != serviceId || slot.providerId != current.providerId) {
      return const Err(BookingFailure.serviceMismatch);
    }
    if (!slot.start.isAfter(_clock.now())) {
      return const Err(BookingFailure.slotInThePast);
    }
    final offering = await _offerings.find(
      providerId: slot.providerId,
      serviceId: serviceId,
    );
    if (!isWithinBookingWindow(
      slot.start,
      _clock.now(),
      offering?.bookingWindow ?? const BookingWindow(),
    )) {
      return const Err(BookingFailure.outsideBookingWindow);
    }
    if (offering != null && !offering.isOpenAt(slot.start)) {
      return const Err(BookingFailure.notOpen);
    }
    final snapshot = await snapshotVehicles(
      profiles: _profiles,
      userId: userId,
      serviceId: serviceId,
      vehicleIds: vehicleIds,
    );
    switch (snapshot) {
      case Err(:final error):
        return Err(error);
      case Success(:final value):
        final treatment = await loadTreatmentQuote(
          offerings: _offerings,
          providerId: slot.providerId,
          serviceId: serviceId,
          treatmentId: treatmentId,
        );
        if (treatment case Err(:final error)) {
          return Err(error);
        }
        final chosenTreatment = switch (treatment) {
          Success(:final value) => value,
          Err() => null,
        };
        final wash = chosenTreatment != null
            ? Success<WashQuote?, BookingFailure>(chosenTreatment)
            : await loadWashQuote(
                washes: _washes,
                providerId: slot.providerId,
                serviceId: serviceId,
                vehicleIds: value.vehicleIds,
                vehicleTypes: value.vehicleTypes,
                vehicleWashes: vehicleWashes,
                washId: washId,
              );
        switch (wash) {
          case Err(:final error):
            return Err(error);
          case Success(value: final chosen):
            final updated = await _scheduling.reschedule(
              appointmentId: appointmentId,
              userId: userId,
              slotId: slotId,
              vehicleLabel: value.label,
              priceCents: chosen?.priceCents ?? value.priceCents,
              vehicleIds: value.vehicleIds,
              duration: chosen?.duration,
              washId: chosen?.washId,
              washName: chosen?.washName,
              vehicleWashes: chosen?.vehicleWashes ?? const {},
              status: current.status == AppointmentStatus.declined
                  ? (offering?.autoConfirm == false
                        ? AppointmentStatus.pending
                        : AppointmentStatus.booked)
                  : null,
            );
            if (updated case Success(value: final booked)
                when booked.status == AppointmentStatus.pending &&
                    current.status != AppointmentStatus.pending) {
              await _notices.requested(booked);
            }
            return updated;
        }
    }
  }
}

final class ConfirmAppointment {
  const ConfirmAppointment({
    required SchedulingRepository scheduling,
    required RecordBookingNotice notices,
  }) : _scheduling = scheduling,
       _notices = notices;

  final SchedulingRepository _scheduling;
  final RecordBookingNotice _notices;

  Future<Result<Appointment, BookingFailure>> call({
    required String providerId,
    required String appointmentId,
  }) async {
    final result = await _scheduling.confirmAppointment(
      providerId: providerId,
      appointmentId: appointmentId,
    );
    if (result case Success(:final value)) {
      await _notices.confirmed(value);
    }
    return result;
  }
}

final class DeclineAppointment {
  const DeclineAppointment({
    required SchedulingRepository scheduling,
    required RecordBookingNotice notices,
  }) : _scheduling = scheduling,
       _notices = notices;

  final SchedulingRepository _scheduling;
  final RecordBookingNotice _notices;

  Future<Result<Appointment, BookingFailure>> call({
    required String providerId,
    required String appointmentId,
    required String message,
    DateTime? suggestedFrom,
    DateTime? suggestedUntil,
  }) async {
    final note = message.trim();
    if (note.isEmpty) {
      return const Err(BookingFailure.missingDeclineMessage);
    }
    final from = suggestedFrom == null
        ? null
        : DateTime(suggestedFrom.year, suggestedFrom.month, suggestedFrom.day);
    final until = suggestedUntil == null
        ? null
        : DateTime(
            suggestedUntil.year,
            suggestedUntil.month,
            suggestedUntil.day,
          );
    if ((from == null) != (until == null) ||
        (from != null && until != null && until.isBefore(from))) {
      return const Err(BookingFailure.invalidSuggestedRange);
    }
    final result = await _scheduling.declineAppointment(
      providerId: providerId,
      appointmentId: appointmentId,
      message: note,
      suggestedFrom: from,
      suggestedUntil: until,
    );
    if (result case Success(:final value)) {
      await _notices.declined(value);
    }
    return result;
  }
}

final class CancelAppointment {
  const CancelAppointment(this._scheduling);

  final SchedulingRepository _scheduling;

  Future<Result<Appointment, BookingFailure>> call({
    required String userId,
    required String appointmentId,
  }) {
    return _scheduling.cancelAppointment(
      userId: userId,
      appointmentId: appointmentId,
    );
  }
}

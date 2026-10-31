import 'package:community_app/core/clock.dart';
import 'package:community_app/core/id_generator.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
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

final class BookAppointment {
  const BookAppointment({
    required SchedulingRepository scheduling,
    required ProfileRepository profiles,
    required WashRepository washes,
    required OfferingRepository offerings,
    required CatalogRepository catalog,
    required IdGenerator ids,
    required Clock clock,
    required RecordBookingNotice notices,
  }) : _scheduling = scheduling,
       _profiles = profiles,
       _washes = washes,
       _offerings = offerings,
       _catalog = catalog,
       _ids = ids,
       _clock = clock,
       _notices = notices;

  final SchedulingRepository _scheduling;
  final ProfileRepository _profiles;
  final WashRepository _washes;
  final OfferingRepository _offerings;
  final CatalogRepository _catalog;
  final IdGenerator _ids;
  final Clock _clock;
  final RecordBookingNotice _notices;

  Future<Result<Appointment, BookingFailure>> call({
    required String userId,
    required String slotId,
    required String serviceId,
    List<String> vehicleIds = const [],
    String? washId,
    String? treatmentId,
    Map<String, String> vehicleWashes = const {},
  }) async {
    final slot = await _scheduling.findSlot(slotId);
    if (slot == null) {
      return const Err(BookingFailure.slotNotFound);
    }
    if (slot.serviceId != serviceId) {
      return const Err(BookingFailure.serviceMismatch);
    }
    final provider = await _catalog.findProvider(slot.providerId);
    final service = await _catalog.findService(serviceId);
    if (provider == null ||
        service == null ||
        !service.active ||
        !provider.isActive(serviceId)) {
      return const Err(BookingFailure.serviceUnavailable);
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
    final existing = await _scheduling.activeAppointmentFor(
      userId: userId,
      slotId: slotId,
    );
    if (existing != null) {
      return const Err(BookingFailure.alreadyBooked);
    }
    if (!slot.hasCapacity) {
      return const Err(BookingFailure.slotFull);
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
            final reserved = await _scheduling.tryReserve(
              appointmentId: _ids.next('appointment'),
              userId: userId,
              slotId: slotId,
              vehicleLabel: value.label,
              priceCents: chosen?.priceCents ?? value.priceCents,
              vehicleIds: value.vehicleIds,
              duration: chosen?.duration,
              washId: chosen?.washId,
              washName: chosen?.washName,
              vehicleWashes: chosen?.vehicleWashes ?? const {},
              status: offering?.autoConfirm == false
                  ? AppointmentStatus.pending
                  : AppointmentStatus.booked,
            );
            if (reserved case Success(
              value: final booked,
            ) when booked.status == AppointmentStatus.pending) {
              await _notices.requested(booked);
            }
            return reserved;
        }
    }
  }
}

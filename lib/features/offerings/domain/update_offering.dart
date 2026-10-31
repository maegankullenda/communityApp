import 'package:community_app/core/clock.dart';
import 'package:community_app/core/id_generator.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/offerings/domain/offer_service.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

final class UpdateOffering {
  const UpdateOffering({
    required CatalogRepository catalog,
    required OfferingRepository offerings,
    required SchedulingRepository scheduling,
    required IdGenerator ids,
    required Clock clock,
  }) : _catalog = catalog,
       _offerings = offerings,
       _scheduling = scheduling,
       _ids = ids,
       _clock = clock;

  final CatalogRepository _catalog;
  final OfferingRepository _offerings;
  final SchedulingRepository _scheduling;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<CommunityService, OfferFailure>> call({
    required String providerId,
    required String serviceId,
    required String offeringName,
    required String offeringDescription,
    List<int> openHours = const [],
    List<int> weekdayHours = const [],
    List<int> weekendHours = const [],
    List<int> openWeekdays = const [],
    int advanceAmount = 0,
    AdvanceUnit advanceUnit = AdvanceUnit.hour,
    int openForAmount = 1,
    AdvanceUnit openForUnit = AdvanceUnit.week,
    bool autoConfirm = true,
    int concurrentBookings = 1,
    List<TreatmentDraft> treatments = const [],
  }) async {
    final provider = await _catalog.findProvider(providerId);
    if (provider == null || !provider.serviceIds.contains(serviceId)) {
      return const Err(OfferFailure.unknownProvider);
    }
    final service = await _catalog.findService(serviceId);
    if (service == null) {
      return const Err(OfferFailure.unknownService);
    }

    final name = offeringName.trim();
    final description = offeringDescription.trim();
    if (name.isEmpty) {
      return const Err(OfferFailure.missingName);
    }

    final days = <int>{};
    for (final day in openWeekdays) {
      if (day < 1 || day > 7) {
        return const Err(OfferFailure.missingHours);
      }
      days.add(day);
    }
    final split = splitOpeningHours(
      openHours: openHours,
      weekdayHours: weekdayHours,
      weekendHours: weekendHours,
      openWeekdays: days.toList(),
    );
    if (split == null) {
      return const Err(OfferFailure.missingHours);
    }
    final bookingWindow = BookingWindow(
      advanceAmount: advanceAmount,
      advanceUnit: advanceUnit,
      openForAmount: openForAmount,
      openForUnit: openForUnit,
    );
    if (!bookingWindowIsValid(bookingWindow)) {
      return const Err(OfferFailure.invalidBookingWindow);
    }
    if (service.fulfillment == FulfillmentKind.appointment &&
        concurrentBookings < 1) {
      return const Err(OfferFailure.invalidConcurrentBookings);
    }

    final savedTreatments = <Treatment>[];
    if (service.id == beautyServiceId) {
      if (treatments.isEmpty) {
        return const Err(OfferFailure.missingTreatment);
      }
      final names = <String>{};
      for (final draft in treatments) {
        final treatmentName = draft.name.trim();
        if (treatmentName.isEmpty) {
          return const Err(OfferFailure.missingName);
        }
        if (!names.add(treatmentName.toLowerCase())) {
          return const Err(OfferFailure.duplicateTreatment);
        }
        final durationHours = draft.durationHours;
        if (durationHours == null ||
            !washDurationHours.contains(durationHours)) {
          return const Err(OfferFailure.invalidDuration);
        }
        final treatmentPrice = draft.priceCents;
        if (treatmentPrice == null || treatmentPrice <= 0) {
          return const Err(OfferFailure.invalidPrice);
        }
        savedTreatments.add(
          Treatment(
            id: draft.id ?? _ids.next('treatment'),
            providerId: providerId,
            serviceId: service.id,
            name: treatmentName,
            description: draft.description.trim(),
            duration: Duration(hours: durationHours),
            priceCents: treatmentPrice,
          ),
        );
      }
    }

    final publishedWeekdayHours = split.weekdayHours;
    final publishedWeekendHours = split.weekendHours;
    final publishedHours = {
      ...publishedWeekdayHours,
      ...publishedWeekendHours,
    }.toList()..sort();
    final publishedDays = days.toList()..sort();
    final offering = ServiceOffering(
      providerId: providerId,
      serviceId: service.id,
      name: name,
      description: description,
      openHours: publishedHours,
      weekdayHours: publishedWeekdayHours,
      weekendHours: publishedWeekendHours,
      openWeekdays: publishedDays,
      advanceAmount: bookingWindow.advanceAmount,
      advanceUnit: bookingWindow.advanceUnit,
      openForAmount: bookingWindow.openForAmount,
      openForUnit: bookingWindow.openForUnit,
      autoConfirm: autoConfirm,
      concurrentBookings: concurrentBookings,
    );
    await _offerings.save(offering);
    if (service.id == beautyServiceId) {
      await _offerings.replaceTreatments(
        providerId: providerId,
        serviceId: service.id,
        treatments: savedTreatments,
      );
    }
    if (service.fulfillment == FulfillmentKind.appointment) {
      await _syncHours(
        providerId: providerId,
        serviceId: service.id,
        weekdayHours: publishedWeekdayHours,
        weekendHours: publishedWeekendHours,
        weekdays: publishedDays,
        window: bookingWindow,
        concurrentBookings: concurrentBookings,
      );
    }
    return Success(service);
  }

  Future<void> _syncHours({
    required String providerId,
    required String serviceId,
    required List<int> weekdayHours,
    required List<int> weekendHours,
    required List<int> weekdays,
    required BookingWindow window,
    required int concurrentBookings,
  }) async {
    final now = _clock.now();
    final days = scheduledDays(now, weekdays, window: window);
    final allowed = weekdays.isEmpty ? everyDay : weekdays;
    final scanStart = DateTime(now.year, now.month, now.day);
    final rangeStart = scanStart;
    final rangeEnd = scanStart.add(const Duration(days: 370));
    final existing = await _scheduling.slotsFor(
      serviceId: serviceId,
      providerId: providerId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    final wanted = <DateTime>{
      for (final day in days)
        if (allowed.contains(day.weekday))
          for (final hour in hoursOnDay(
            weekday: day.weekday,
            weekdayHours: weekdayHours,
            weekendHours: weekendHours,
          ))
            if (isWithinBookingWindow(
              DateTime(day.year, day.month, day.day, hour),
              now,
              window,
            ))
              DateTime(day.year, day.month, day.day, hour),
    };

    for (final slot in existing) {
      final start = DateTime(
        slot.start.year,
        slot.start.month,
        slot.start.day,
        slot.start.hour,
        slot.start.minute,
      );
      if (!wanted.contains(start)) {
        await _scheduling.removeSlot(slot.id);
      }
    }
    for (final start in wanted) {
      TimeSlot? current;
      for (final slot in existing) {
        if (slot.start.year == start.year &&
            slot.start.month == start.month &&
            slot.start.day == start.day &&
            slot.start.hour == start.hour &&
            slot.start.minute == start.minute) {
          current = slot;
        }
      }
      await _scheduling.publishSlot(
        TimeSlot(
          id:
              current?.id ??
              openingSlotId(
                serviceId: serviceId,
                providerId: providerId,
                start: start,
              ),
          providerId: providerId,
          serviceId: serviceId,
          start: current?.start ?? start,
          duration: current?.duration ?? const Duration(hours: 1),
          capacity: concurrentBookings,
          bookedCount: current?.bookedCount ?? 0,
        ),
      );
    }
  }
}

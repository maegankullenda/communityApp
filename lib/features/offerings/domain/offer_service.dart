import 'package:community_app/core/clock.dart';
import 'package:community_app/core/id_generator.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

enum OfferFailure {
  unknownService,
  alreadyOffered,
  unknownProvider,
  missingItem,
  invalidPrice,
  missingName,
  missingHours,
  missingTreatment,
  invalidDuration,
  duplicateTreatment,
  invalidBookingWindow,
  invalidConcurrentBookings,
}

final class OfferService {
  const OfferService({
    required CatalogRepository catalog,
    required SchedulingRepository scheduling,
    required OrderingRepository ordering,
    required OfferingRepository offerings,
    required IdGenerator ids,
    required Clock clock,
  }) : _catalog = catalog,
       _scheduling = scheduling,
       _ordering = ordering,
       _offerings = offerings,
       _ids = ids,
       _clock = clock;

  final CatalogRepository _catalog;
  final SchedulingRepository _scheduling;
  final OrderingRepository _ordering;
  final OfferingRepository _offerings;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<CommunityService, OfferFailure>> call({
    required String providerId,
    required String serviceId,
    String? itemName,
    int? priceCents,
    String? offeringName,
    String? offeringDescription,
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
    if (provider == null) {
      return const Err(OfferFailure.unknownProvider);
    }
    final service = await _catalog.findService(serviceId);
    if (service == null) {
      return const Err(OfferFailure.unknownService);
    }
    if (provider.serviceIds.contains(serviceId)) {
      return const Err(OfferFailure.alreadyOffered);
    }

    final trimmedItemName = itemName?.trim() ?? '';
    final name = offeringName?.trim() ?? '';
    final description = offeringDescription?.trim() ?? '';
    final configured =
        name.isNotEmpty ||
        description.isNotEmpty ||
        openHours.isNotEmpty ||
        weekdayHours.isNotEmpty ||
        weekendHours.isNotEmpty ||
        treatments.isNotEmpty;
    if (service.fulfillment == FulfillmentKind.order) {
      if (trimmedItemName.isEmpty) {
        return const Err(OfferFailure.missingItem);
      }
      if (priceCents == null || priceCents <= 0) {
        return const Err(OfferFailure.invalidPrice);
      }
    }
    if (configured && name.isEmpty) {
      return const Err(OfferFailure.missingName);
    }

    final days = <int>{};
    if (configured) {
      for (final day in openWeekdays) {
        if (day < 1 || day > 7) {
          return const Err(OfferFailure.missingHours);
        }
        days.add(day);
      }
    }
    final split = configured
        ? splitOpeningHours(
            openHours: openHours,
            weekdayHours: weekdayHours,
            weekendHours: weekendHours,
            openWeekdays: days.toList(),
          )
        : null;
    if (configured && split == null) {
      return const Err(OfferFailure.missingHours);
    }
    final bookingWindow = BookingWindow(
      advanceAmount: advanceAmount,
      advanceUnit: advanceUnit,
      openForAmount: openForAmount,
      openForUnit: openForUnit,
    );
    if (configured && !bookingWindowIsValid(bookingWindow)) {
      return const Err(OfferFailure.invalidBookingWindow);
    }
    if (service.fulfillment == FulfillmentKind.appointment &&
        concurrentBookings < 1) {
      return const Err(OfferFailure.invalidConcurrentBookings);
    }
    final savedTreatments = <Treatment>[];
    if (service.id == beautyServiceId && configured) {
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
            id: _ids.next('treatment'),
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

    final publishedWeekdayHours =
        split?.weekdayHours ??
        (service.fulfillment == FulfillmentKind.appointment
            ? openingHoursFor(service.id)
            : const <int>[]);
    final publishedWeekendHours = split?.weekendHours ?? publishedWeekdayHours;
    final publishedHours = {
      ...publishedWeekdayHours,
      ...publishedWeekendHours,
    }.toList()..sort();
    final publishedDays = days.toList()..sort();

    await _catalog.saveProvider(provider.withService(service.id));
    if (name.isNotEmpty) {
      await _offerings.save(
        ServiceOffering(
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
        ),
      );
    }
    if (savedTreatments.isNotEmpty) {
      await _offerings.replaceTreatments(
        providerId: providerId,
        serviceId: service.id,
        treatments: savedTreatments,
      );
    }
    await _publishOpening(
      service: service,
      providerId: providerId,
      itemName: trimmedItemName,
      itemDescription: description.isEmpty ? service.summary : description,
      priceCents: priceCents,
      weekdayHours: publishedWeekdayHours,
      weekendHours: publishedWeekendHours,
      weekdays: publishedDays,
      window: bookingWindow,
      concurrentBookings: concurrentBookings,
    );
    return Success(service);
  }

  Future<void> _publishOpening({
    required CommunityService service,
    required String providerId,
    required String itemName,
    required String itemDescription,
    required int? priceCents,
    required List<int> weekdayHours,
    required List<int> weekendHours,
    required List<int> weekdays,
    required BookingWindow window,
    required int concurrentBookings,
  }) async {
    final now = _clock.now();
    switch (service.fulfillment) {
      case FulfillmentKind.appointment:
        for (final day in scheduledDays(now, weekdays, window: window)) {
          final hours = hoursOnDay(
            weekday: day.weekday,
            weekdayHours: weekdayHours,
            weekendHours: weekendHours,
          );
          for (final hour in hours) {
            final start = DateTime(day.year, day.month, day.day, hour);
            if (!isWithinBookingWindow(start, now, window)) {
              continue;
            }
            await _scheduling.publishSlot(
              TimeSlot(
                id: openingSlotId(
                  serviceId: service.id,
                  providerId: providerId,
                  start: start,
                ),
                providerId: providerId,
                serviceId: service.id,
                start: start,
                duration: const Duration(hours: 1),
                capacity: concurrentBookings,
              ),
            );
          }
        }
      case FulfillmentKind.order:
        final availableFrom = DateTime(now.year, now.month, now.day);
        await _ordering.publishItem(
          MenuItem(
            id: _ids.next('item'),
            providerId: providerId,
            serviceId: service.id,
            name: itemName,
            description: itemDescription,
            priceCents: priceCents!,
            availableFrom: availableFrom,
            availableUntil: availableFrom.add(const Duration(days: 7)),
          ),
        );
    }
  }
}

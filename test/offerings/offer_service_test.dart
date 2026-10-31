import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/offerings/domain/offer_service.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/ordering/domain/place_order.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('a provider can join an existing appointment service', () async {
    final harness = AppHarness();

    final service = successValue(
      await harness.offerService.call(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
      ),
    );

    expect(service.name, 'Beauty');
    expect((await harness.catalog.listServices()).length, 3);
    final providers = await harness.catalog.providersFor('beauty');
    expect(
      providers.map((provider) => provider.id),
      containsAll(['riley-studio', 'maegans-rides']),
    );

    final slots = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    expect(slots.map((slot) => slot.start.hour), [9, 11, 13, 15]);
    final week = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 13),
    );
    expect(week, hasLength(24));
    final nine = slots.firstWhere((slot) => slot.start.hour == 9);
    successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: nine.id,
        serviceId: 'beauty',
      ),
    );
    final second = await harness.bookAppointment.call(
      userId: 'neighbour',
      slotId: nine.id,
      serviceId: 'beauty',
    );
    expect(failureError(second), BookingFailure.slotFull);
  });

  test(
    'a beauty offering keeps its name, hours, and treatment price',
    () async {
      final harness = AppHarness();

      successValue(
        await harness.offerService.call(
          providerId: 'maegans-rides',
          serviceId: 'beauty',
          offeringName: 'Maegan beauty parlor',
          offeringDescription: 'Cuts and colour',
          openHours: [10, 14],
          treatments: const [
            TreatmentDraft(
              name: 'Cut and colour',
              description: 'A full colour',
              durationHours: 1,
              priceCents: 20000,
            ),
          ],
        ),
      );

      final offering = await harness.offerings.find(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
      );
      expect(offering?.name, 'Maegan beauty parlor');
      expect(offering?.openHours, [10, 14]);
      expect(offering?.openWeekdays, isEmpty);
      final slots = await harness.scheduling.slotsFor(
        serviceId: 'beauty',
        providerId: 'maegans-rides',
        rangeStart: DateTime(2026, 10, 6),
        rangeEnd: DateTime(2026, 10, 7),
      );
      expect(slots.map((slot) => slot.start.hour), [10, 14]);
      final treatments = await harness.offerings.treatmentsFor(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
      );
      final booked = successValue(
        await harness.bookAppointment.call(
          userId: 'alex',
          slotId: slots.first.id,
          serviceId: 'beauty',
          treatmentId: treatments.single.id,
        ),
      );
      expect(booked.priceCents, 20000);
      expect(booked.washName, 'Cut and colour');
      expect(booked.duration, const Duration(hours: 1));

      final missing = await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots.last.id,
        serviceId: 'beauty',
      );
      expect(failureError(missing), BookingFailure.treatmentRequired);
    },
  );

  test('weekend hours are the only bookable times', () async {
    final harness = AppHarness();

    successValue(
      await harness.offerService.call(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
        offeringName: 'Cookies hive',
        offeringDescription: 'Weekend treatments',
        openHours: [10, 14],
        openWeekdays: [6, 7],
        treatments: const [
          TreatmentDraft(
            name: 'Facial',
            description: 'A weekend facial',
            durationHours: 1,
            priceCents: 20000,
          ),
        ],
      ),
    );

    final tuesday = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    expect(tuesday, isEmpty);
    final weekend = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 10),
      rangeEnd: DateTime(2026, 10, 12),
    );
    expect(weekend.map((slot) => slot.start.weekday), [6, 6, 7, 7]);
    expect(weekend.map((slot) => slot.start.hour), [10, 14, 10, 14]);
  });

  test('weekday times and weekend times can differ', () async {
    final harness = AppHarness();

    successValue(
      await harness.offerService.call(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
        offeringName: 'Cookies hive',
        offeringDescription: 'Different hours each part of the week',
        weekdayHours: [9, 15],
        weekendHours: [11, 16],
        treatments: const [
          TreatmentDraft(
            name: 'Facial',
            description: 'A facial',
            durationHours: 1,
            priceCents: 20000,
          ),
        ],
      ),
    );

    final tuesday = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    expect(tuesday.map((slot) => slot.start.hour), [9, 15]);
    final saturday = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 10),
      rangeEnd: DateTime(2026, 10, 11),
    );
    expect(saturday.map((slot) => slot.start.hour), [11, 16]);
  });

  test(
    'a leftover weekday time cannot be booked when that day is closed',
    () async {
      final harness = AppHarness();

      successValue(
        await harness.offerService.call(
          providerId: 'maegans-rides',
          serviceId: 'beauty',
          offeringName: 'Cookies hive',
          offeringDescription: 'Weekends only',
          weekendHours: [11, 16],
          openWeekdays: [6, 7],
          treatments: const [
            TreatmentDraft(
              name: 'Facial',
              description: 'A facial',
              durationHours: 1,
              priceCents: 20000,
            ),
          ],
        ),
      );
      final leftover = TimeSlot(
        id: 'leftover-monday',
        providerId: 'maegans-rides',
        serviceId: 'beauty',
        start: DateTime(2026, 10, 5, 9),
        duration: Duration(hours: 1),
        capacity: 1,
      );
      await harness.scheduling.publishSlot(leftover);
      final treatments = await harness.offerings.treatmentsFor(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
      );

      final booked = await harness.bookAppointment.call(
        userId: 'alex',
        slotId: leftover.id,
        serviceId: 'beauty',
        treatmentId: treatments.single.id,
      );

      expect(failureError(booked), BookingFailure.notOpen);
    },
  );

  test('open times can be any hour from midnight to 23:00', () async {
    final harness = AppHarness();

    successValue(
      await harness.offerService.call(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
        offeringName: 'Cookies hive',
        offeringDescription: 'Open overnight',
        weekdayHours: [0, 23],
        openWeekdays: [2],
        treatments: const [
          TreatmentDraft(
            name: 'Facial',
            description: 'A facial',
            durationHours: 1,
            priceCents: 20000,
          ),
        ],
      ),
    );

    final tuesday = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    expect(tuesday.map((slot) => slot.start.hour), [0, 23]);
    final monday = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 5),
      rangeEnd: DateTime(2026, 10, 6),
    );
    expect(monday, isEmpty);

    final invalid = await harness.offerService.call(
      providerId: 'sam-shine',
      serviceId: 'beauty',
      offeringName: 'Night wash',
      offeringDescription: 'Too late',
      weekdayHours: [24],
      openWeekdays: [1],
      treatments: const [
        TreatmentDraft(
          name: 'Facial',
          description: 'A facial',
          durationHours: 1,
          priceCents: 20000,
        ),
      ],
    );
    expect(failureError(invalid), OfferFailure.missingHours);
  });

  test('customers can only book inside the configured window', () async {
    final harness = AppHarness();

    successValue(
      await harness.offerService.call(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
        offeringName: 'Cookies hive',
        offeringDescription: 'Opens tomorrow for a month',
        weekdayHours: [10],
        weekendHours: [10],
        advanceAmount: 1,
        advanceUnit: AdvanceUnit.day,
        openForAmount: 1,
        openForUnit: AdvanceUnit.month,
        treatments: const [
          TreatmentDraft(
            name: 'Facial',
            description: 'A facial',
            durationHours: 1,
            priceCents: 20000,
          ),
        ],
      ),
    );

    final today = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 5),
      rangeEnd: DateTime(2026, 10, 6),
    );
    expect(today, isEmpty);
    final tomorrow = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    expect(tomorrow.map((slot) => slot.start.hour), [10]);
    final lastDay = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 11, 5),
      rangeEnd: DateTime(2026, 11, 6),
    );
    expect(lastDay.map((slot) => slot.start.hour), [10]);
    final after = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 11, 6),
      rangeEnd: DateTime(2026, 11, 7),
    );
    expect(after, isEmpty);

    final treatments = await harness.offerings.treatmentsFor(
      providerId: 'maegans-rides',
      serviceId: 'beauty',
    );
    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: tomorrow.single.id,
        serviceId: 'beauty',
        treatmentId: treatments.single.id,
      ),
    );
    expect(booked.start, DateTime(2026, 10, 6, 10));
  });

  test('next week can be open for one week only', () async {
    final harness = AppHarness();

    successValue(
      await harness.offerService.call(
        providerId: 'maegans-rides',
        serviceId: 'beauty',
        offeringName: 'Cookies hive',
        offeringDescription: 'Next week only',
        openHours: [9],
        advanceUnit: AdvanceUnit.nextWeek,
        openForAmount: 1,
        openForUnit: AdvanceUnit.week,
        treatments: const [
          TreatmentDraft(
            name: 'Facial',
            description: 'A facial',
            durationHours: 1,
            priceCents: 20000,
          ),
        ],
      ),
    );

    final before = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 5),
      rangeEnd: DateTime(2026, 10, 12),
    );
    expect(before, isEmpty);
    final first = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 12),
      rangeEnd: DateTime(2026, 10, 13),
    );
    expect(first.map((slot) => slot.start.hour), [9]);
    final last = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 18),
      rangeEnd: DateTime(2026, 10, 19),
    );
    expect(last.map((slot) => slot.start.hour), [9]);
    final after = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 19),
      rangeEnd: DateTime(2026, 10, 20),
    );
    expect(after, isEmpty);
  });

  test('a provider can join an existing order service', () async {
    final harness = AppHarness();

    final service = successValue(
      await harness.offerService.call(
        providerId: 'sam-shine',
        serviceId: 'foodie',
        itemName: ' Seed loaf ',
        priceCents: 4500,
      ),
    );

    expect(service.name, 'Foodie');
    final providers = await harness.catalog.providersFor('foodie');
    expect(providers.map((provider) => provider.id), contains('sam-shine'));
    final items = await harness.ordering.itemsFor(
      serviceId: 'foodie',
      providerId: 'sam-shine',
    );
    final order = successValue(
      await harness.placeOrder.call(
        userId: 'alex',
        serviceId: 'foodie',
        lines: [OrderRequestLine(itemId: items.single.id, quantity: 1)],
      ),
    );

    expect(items.single.name, 'Seed loaf');
    expect(order.totalCents, 4500);
  });

  test('an invalid price does not add the provider', () async {
    final harness = AppHarness();

    final result = await harness.offerService.call(
      providerId: 'sam-shine',
      serviceId: 'foodie',
      itemName: 'Tomato soup',
      priceCents: 0,
    );

    expect(failureError(result), OfferFailure.invalidPrice);
    final providers = await harness.catalog.providersFor('foodie');
    expect(
      providers.map((provider) => provider.id),
      isNot(contains('sam-shine')),
    );
  });

  test('joining a service you already offer adds nothing', () async {
    final harness = AppHarness();
    final before = await harness.scheduling.slotsFor(
      serviceId: 'car-wash',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 1),
      rangeEnd: DateTime(2026, 11, 1),
    );

    final result = await harness.offerService.call(
      providerId: 'maegans-rides',
      serviceId: 'car-wash',
    );

    expect(failureError(result), OfferFailure.alreadyOffered);
    final after = await harness.scheduling.slotsFor(
      serviceId: 'car-wash',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 1),
      rangeEnd: DateTime(2026, 11, 1),
    );
    expect(after.length, before.length);
  });
}

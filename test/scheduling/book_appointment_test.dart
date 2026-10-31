import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/offerings/domain/offer_service.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/update_offering.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';
import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  Future<TimeSlot> firstCarWashSlot(AppHarness harness) async {
    final slots = await harness.scheduling.slotsFor(
      serviceId: 'car-wash',
      providerId: 'sam-shine',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    return slots.first;
  }

  test('booking a car wash holds the slot for that customer', () async {
    final harness = AppHarness();
    final slot = await firstCarWashSlot(harness);
    final vehicleId = await harness.ensureVehicle('alex');

    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slot.id,
        serviceId: 'car-wash',
        vehicleIds: [vehicleId],
      ),
    );

    expect(booked.userId, 'alex');
    expect(booked.providerId, 'sam-shine');
    expect(booked.start, slot.start);
    expect(booked.vehicleLabel, 'Daily (Hatch)');
    expect(booked.priceCents, 12000);

    final stored = await harness.scheduling.findSlot(slot.id);
    expect(stored!.hasCapacity, isFalse);

    final providerBookings = await harness.loadProviderBookings.call(
      'sam-shine',
    );
    expect(providerBookings, hasLength(1));
    expect(providerBookings.single.customerName, 'Alex');
    expect(providerBookings.single.serviceName, 'Car wash');
  });

  test('a provider booking includes how to reach the customer', () async {
    final harness = AppHarness();
    final slot = await firstCarWashSlot(harness);
    successValue(
      await harness.saveProfile.call(
        accountId: 'alex',
        firstName: 'Alex',
        surname: 'Nkosi',
        address: '14 Oak Street',
        contactNumber: '0821234567',
        vehicles: const [VehicleInput(name: 'Daily', type: VehicleType.hatch)],
      ),
    );
    final vehicleId = (await harness.profiles.find('alex')).vehicles.single.id;
    successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slot.id,
        serviceId: 'car-wash',
        vehicleIds: [vehicleId],
      ),
    );

    final booking = (await harness.loadProviderBookings.call(
      'sam-shine',
    )).single;
    expect(booking.customerFirstName, 'Alex');
    expect(booking.customerSurname, 'Nkosi');
    expect(booking.contactNumber, '0821234567');
    expect(booking.address, '14 Oak Street');
  });

  test('several vehicles on one wash are priced together', () async {
    final harness = AppHarness();
    final slot = await firstCarWashSlot(harness);
    final hatchId = await harness.ensureVehicle('alex', name: 'City run');
    final suvId = await harness.ensureVehicle(
      'alex',
      name: 'Weekend',
      type: VehicleType.suv,
    );

    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slot.id,
        serviceId: 'car-wash',
        vehicleIds: [hatchId, suvId],
      ),
    );

    expect(booked.vehicleLabel, 'City run (Hatch), Weekend (SUV)');
    expect(booked.priceCents, 34000);
    expect((await harness.scheduling.findSlot(slot.id))!.hasCapacity, isFalse);
  });

  test('a second customer cannot take a full slot', () async {
    final harness = AppHarness();
    final slot = await firstCarWashSlot(harness);
    final vehicleId = await harness.ensureVehicle('alex');
    await harness.bookAppointment.call(
      userId: 'alex',
      slotId: slot.id,
      serviceId: 'car-wash',
      vehicleIds: [vehicleId],
    );

    final second = await harness.bookAppointment.call(
      userId: 'neighbour',
      slotId: slot.id,
      serviceId: 'car-wash',
    );

    expect(failureError(second), BookingFailure.slotFull);

    final hours = openingHoursFor('car-wash');
    final updater = UpdateOffering(
      catalog: harness.catalog,
      offerings: harness.offerings,
      scheduling: harness.scheduling,
      ids: harness.ids,
      clock: harness.clock,
    );
    successValue(
      await updater.call(
        providerId: 'sam-shine',
        serviceId: 'car-wash',
        offeringName: "Sam's Shine",
        offeringDescription: 'Driveway washes',
        weekdayHours: hours,
        weekendHours: hours,
        concurrentBookings: 2,
      ),
    );
    final opened = await harness.scheduling.findSlot(slot.id);
    expect(opened!.capacity, 2);
    expect(opened.bookedCount, 1);
    final neighbourVehicle = await harness.ensureVehicle(
      'neighbour',
      name: 'Van',
    );
    successValue(
      await harness.bookAppointment.call(
        userId: 'neighbour',
        slotId: slot.id,
        serviceId: 'car-wash',
        vehicleIds: [neighbourVehicle],
      ),
    );
    expect((await harness.scheduling.findSlot(slot.id))!.bookedCount, 2);
    final third = await harness.bookAppointment.call(
      userId: 'someone',
      slotId: slot.id,
      serviceId: 'car-wash',
    );
    expect(failureError(third), BookingFailure.slotFull);

    final invalid = await updater.call(
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      offeringName: "Sam's Shine",
      offeringDescription: 'Driveway washes',
      weekdayHours: hours,
      weekendHours: hours,
      concurrentBookings: 0,
    );
    expect(failureError(invalid), OfferFailure.invalidConcurrentBookings);
    final bookings = await harness.scheduling.appointmentsForProvider(
      'sam-shine',
    );
    expect(bookings, hasLength(2));
  });

  test('the same customer cannot book one slot twice', () async {
    final harness = AppHarness();
    final open = TimeSlot(
      id: 'shared',
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      start: DateTime(2026, 10, 6, 18),
      duration: const Duration(hours: 1),
      capacity: 2,
    );
    await harness.scheduling.publishSlot(open);
    final vehicleId = await harness.ensureVehicle('alex');
    await harness.bookAppointment.call(
      userId: 'alex',
      slotId: open.id,
      serviceId: 'car-wash',
      vehicleIds: [vehicleId],
    );

    final again = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: open.id,
      serviceId: 'car-wash',
    );

    expect(failureError(again), BookingFailure.alreadyBooked);
    final stored = await harness.scheduling.findSlot(open.id);
    expect(stored!.bookedCount, 1);
  });

  test('a past slot stays open and is not booked', () async {
    final harness = AppHarness();
    final past = TimeSlot(
      id: 'past',
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      start: DateTime(2026, 10, 5, 7),
      duration: const Duration(hours: 1),
      capacity: 1,
    );
    await harness.scheduling.publishSlot(past);

    final result = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: past.id,
      serviceId: 'car-wash',
    );

    expect(failureError(result), BookingFailure.slotInThePast);
    expect((await harness.scheduling.findSlot(past.id))!.bookedCount, 0);
  });

  test('a slot cannot be booked under a different service', () async {
    final harness = AppHarness();
    final slot = await firstCarWashSlot(harness);

    final result = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: slot.id,
      serviceId: 'beauty',
    );

    expect(failureError(result), BookingFailure.serviceMismatch);
    expect((await harness.scheduling.findSlot(slot.id))!.bookedCount, 0);
  });

  test('an unknown slot is rejected', () async {
    final harness = AppHarness();

    final result = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: 'missing',
      serviceId: 'car-wash',
    );

    expect(failureError(result), BookingFailure.slotNotFound);
  });

  test('booking one time leaves the other times open', () async {
    final harness = AppHarness();
    final slots = await harness.scheduling.slotsFor(
      serviceId: 'car-wash',
      providerId: 'sam-shine',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );

    final vehicleId = await harness.ensureVehicle('alex');
    await harness.bookAppointment.call(
      userId: 'alex',
      slotId: slots.first.id,
      serviceId: 'car-wash',
      vehicleIds: [vehicleId],
    );

    final remaining = await harness.scheduling.findSlot(slots[1].id);
    expect(remaining!.hasCapacity, isTrue);
  });

  test('beauty uses the same booking rules as car wash', () async {
    final harness = AppHarness();
    final slots = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'riley-studio',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );

    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots.first.id,
        serviceId: 'beauty',
      ),
    );

    expect(booked.providerId, 'riley-studio');
    final samBookings = await harness.loadProviderBookings.call('sam-shine');
    final rileyBookings = await harness.loadProviderBookings.call(
      'riley-studio',
    );
    expect(samBookings, isEmpty);
    expect(rileyBookings.single.serviceName, 'Beauty');
    expect(booked.isConfirmed, isTrue);
  });

  test(
    'a provider can leave new bookings pending until they confirm',
    () async {
      final harness = AppHarness();
      await harness.offerings.save(
        const ServiceOffering(
          providerId: 'riley-studio',
          serviceId: 'beauty',
          name: 'Riley Studio',
          description: '',
          openHours: [9, 11, 13, 15],
          autoConfirm: false,
        ),
      );
      final slots = await harness.scheduling.slotsFor(
        serviceId: 'beauty',
        providerId: 'riley-studio',
        rangeStart: DateTime(2026, 10, 6),
        rangeEnd: DateTime(2026, 10, 7),
      );

      final pending = successValue(
        await harness.bookAppointment.call(
          userId: 'alex',
          slotId: slots.first.id,
          serviceId: 'beauty',
        ),
      );

      expect(pending.status, AppointmentStatus.pending);
      final waiting = await harness.loadProviderBookings.call('riley-studio');
      expect(waiting.single.appointment.status, AppointmentStatus.pending);

      final confirmed = successValue(
        await harness.scheduling.confirmAppointment(
          appointmentId: pending.id,
          providerId: 'riley-studio',
        ),
      );
      expect(confirmed.isConfirmed, isTrue);
      expect(
        (await harness.scheduling.findAppointment(pending.id))!.status,
        AppointmentStatus.booked,
      );
    },
  );

  test('declining a booking keeps the message and frees the time', () async {
    final harness = AppHarness();
    await harness.offerings.save(
      const ServiceOffering(
        providerId: 'riley-studio',
        serviceId: 'beauty',
        name: 'Riley Studio',
        description: '',
        openHours: [9, 11, 13, 15],
        autoConfirm: false,
      ),
    );
    final slots = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'riley-studio',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    final pending = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots.first.id,
        serviceId: 'beauty',
      ),
    );

    final declined = successValue(
      await harness.declineAppointment.call(
        providerId: 'riley-studio',
        appointmentId: pending.id,
        message: '  That morning is full.  ',
        suggestedFrom: DateTime(2026, 10, 12),
        suggestedUntil: DateTime(2026, 10, 18),
      ),
    );

    expect(declined.status, AppointmentStatus.declined);
    expect(declined.declineMessage, 'That morning is full.');
    expect(declined.suggestedFrom, DateTime(2026, 10, 12));
    expect(declined.suggestedUntil, DateTime(2026, 10, 18));
    expect((await harness.scheduling.findSlot(slots.first.id))!.bookedCount, 0);
    final activity = await harness.loadMyActivity.call('alex');
    expect(
      activity.appointments.single.appointment.status,
      AppointmentStatus.declined,
    );
    final waiting = await harness.loadProviderBookings.call('riley-studio');
    expect(waiting, isEmpty);

    final withoutDates = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots[1].id,
        serviceId: 'beauty',
      ),
    );
    final declinedWithoutDates = successValue(
      await harness.declineAppointment.call(
        providerId: 'riley-studio',
        appointmentId: withoutDates.id,
        message: 'We are closed that week.',
      ),
    );
    expect(declinedWithoutDates.declineMessage, 'We are closed that week.');
    expect(declinedWithoutDates.suggestedFrom, isNull);
    expect(declinedWithoutDates.suggestedUntil, isNull);

    final missing = await harness.declineAppointment.call(
      providerId: 'riley-studio',
      appointmentId: pending.id,
      message: '',
      suggestedFrom: DateTime(2026, 10, 12),
      suggestedUntil: DateTime(2026, 10, 11),
    );
    expect(failureError(missing), BookingFailure.missingDeclineMessage);
  });
}

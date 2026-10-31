import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  Future<List<dynamic>> carWashSlots(AppHarness harness) {
    return harness.scheduling.slotsFor(
      serviceId: 'car-wash',
      providerId: 'sam-shine',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
  }

  test('a customer can move a wash to another time', () async {
    final harness = AppHarness();
    final slots = await carWashSlots(harness);
    final vehicleId = await harness.ensureVehicle('alex');
    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots.first.id,
        serviceId: 'car-wash',
        vehicleIds: [vehicleId],
      ),
    );

    final changed = successValue(
      await harness.changeAppointment.call(
        userId: 'alex',
        appointmentId: booked.id,
        slotId: slots[1].id,
        serviceId: 'car-wash',
        vehicleIds: [vehicleId],
      ),
    );

    expect(changed.id, booked.id);
    expect(changed.start, slots[1].start);
    expect(changed.vehicleIds, [vehicleId]);
    expect(
      (await harness.scheduling.findSlot(slots.first.id))!.hasCapacity,
      isTrue,
    );
    expect(
      (await harness.scheduling.findSlot(slots[1].id))!.hasCapacity,
      isFalse,
    );
    final providerBookings = await harness.loadProviderBookings.call(
      'sam-shine',
    );
    expect(providerBookings.single.appointment.id, booked.id);
    expect(providerBookings.single.appointment.start, slots[1].start);
  });

  test('changing the vehicle updates the price and keeps the time', () async {
    final harness = AppHarness();
    final slots = await carWashSlots(harness);
    final hatchId = await harness.ensureVehicle('alex', name: 'City run');
    final suvId = await harness.ensureVehicle(
      'alex',
      name: 'Weekend',
      type: VehicleType.suv,
    );
    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots.first.id,
        serviceId: 'car-wash',
        vehicleIds: [hatchId],
      ),
    );

    final changed = successValue(
      await harness.changeAppointment.call(
        userId: 'alex',
        appointmentId: booked.id,
        slotId: slots.first.id,
        serviceId: 'car-wash',
        vehicleIds: [suvId],
      ),
    );

    expect(changed.priceCents, 22000);
    expect(changed.vehicleLabel, 'Weekend (SUV)');
    expect(changed.slotId, slots.first.id);
    expect((await harness.scheduling.findSlot(slots.first.id))!.bookedCount, 1);
  });

  test('a taken time does not replace the current booking', () async {
    final harness = AppHarness();
    final slots = await carWashSlots(harness);
    final alexVehicle = await harness.ensureVehicle('alex');
    final samVehicle = await harness.ensureVehicle('sam', name: 'Van');
    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots.first.id,
        serviceId: 'car-wash',
        vehicleIds: [alexVehicle],
      ),
    );
    await harness.bookAppointment.call(
      userId: 'sam',
      slotId: slots[1].id,
      serviceId: 'car-wash',
      vehicleIds: [samVehicle],
    );

    final moved = await harness.changeAppointment.call(
      userId: 'alex',
      appointmentId: booked.id,
      slotId: slots[1].id,
      serviceId: 'car-wash',
      vehicleIds: [alexVehicle],
    );

    expect(failureError(moved), BookingFailure.slotFull);
    final stored = await harness.scheduling.findAppointment(booked.id);
    expect(stored!.slotId, slots.first.id);
    expect(
      (await harness.scheduling.findSlot(slots.first.id))!.hasCapacity,
      isFalse,
    );
  });

  test(
    'cancelling a booking opens the time and hides it from the provider',
    () async {
      final harness = AppHarness();
      final slots = await carWashSlots(harness);
      final vehicleId = await harness.ensureVehicle('alex');
      final booked = successValue(
        await harness.bookAppointment.call(
          userId: 'alex',
          slotId: slots.first.id,
          serviceId: 'car-wash',
          vehicleIds: [vehicleId],
        ),
      );

      final cancelled = successValue(
        await harness.cancelAppointment.call(
          userId: 'alex',
          appointmentId: booked.id,
        ),
      );

      expect(cancelled.isActive, isFalse);
      expect(
        (await harness.scheduling.findSlot(slots.first.id))!.hasCapacity,
        isTrue,
      );
      expect(await harness.loadProviderBookings.call('sam-shine'), isEmpty);
      expect((await harness.loadMyActivity.call('alex')).appointments, isEmpty);

      final again = await harness.cancelAppointment.call(
        userId: 'alex',
        appointmentId: booked.id,
      );
      expect(failureError(again), BookingFailure.appointmentNotFound);
    },
  );

  test('editing a declined booking requests the new time', () async {
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
    await harness.declineAppointment.call(
      providerId: 'riley-studio',
      appointmentId: pending.id,
      message: 'That morning is full.',
      suggestedFrom: DateTime(2026, 10, 12),
      suggestedUntil: DateTime(2026, 10, 18),
    );

    final revised = successValue(
      await harness.changeAppointment.call(
        userId: 'alex',
        appointmentId: pending.id,
        slotId: slots[1].id,
        serviceId: 'beauty',
      ),
    );

    expect(revised.id, pending.id);
    expect(revised.status, AppointmentStatus.pending);
    expect(revised.start, slots[1].start);
    expect(revised.declineMessage, isEmpty);
    expect(revised.suggestedFrom, isNull);
    expect((await harness.scheduling.findSlot(slots.first.id))!.bookedCount, 0);
    expect((await harness.scheduling.findSlot(slots[1].id))!.bookedCount, 1);
    final activity = await harness.loadMyActivity.call('alex');
    expect(
      activity.appointments.single.appointment.status,
      AppointmentStatus.pending,
    );
  });

  test(
    'cancelling a declined booking removes it without touching the time',
    () async {
      final harness = AppHarness();
      await harness.offerings.save(
        const ServiceOffering(
          providerId: 'riley-studio',
          serviceId: 'beauty',
          name: 'Riley Studio',
          description: '',
          openHours: [9, 11],
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
      await harness.declineAppointment.call(
        providerId: 'riley-studio',
        appointmentId: pending.id,
        message: 'That morning is full.',
        suggestedFrom: DateTime(2026, 10, 12),
        suggestedUntil: DateTime(2026, 10, 18),
      );

      final cancelled = successValue(
        await harness.cancelAppointment.call(
          userId: 'alex',
          appointmentId: pending.id,
        ),
      );

      expect(cancelled.status, AppointmentStatus.cancelled);
      expect(
        (await harness.scheduling.findSlot(slots.first.id))!.bookedCount,
        0,
      );
      expect((await harness.loadMyActivity.call('alex')).appointments, isEmpty);
    },
  );
}

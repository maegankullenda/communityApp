import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('a wash price is kept and a long wash blocks later times', () async {
    final harness = AppHarness();
    final vehicleId = await harness.ensureVehicle('alex');
    const day = '20261006';

    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: 'car-wash-maegans-rides-$day-0900',
        serviceId: 'car-wash',
        vehicleIds: [vehicleId],
        washId: 'wash-wax',
      ),
    );

    expect(booked.washName, 'Wax and detailing');
    expect(booked.priceCents, 45000);
    expect(booked.duration, const Duration(hours: 4));
    expect(
      (await harness.scheduling.findSlot(
        'car-wash-maegans-rides-$day-0900',
      ))!.bookedCount,
      1,
    );
    expect(
      (await harness.scheduling.findSlot(
        'car-wash-maegans-rides-$day-1100',
      ))!.bookedCount,
      1,
    );
    expect(
      (await harness.scheduling.findSlot(
        'car-wash-maegans-rides-$day-1300',
      ))!.bookedCount,
      0,
    );

    final missing = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: 'car-wash-maegans-rides-$day-1300',
      serviceId: 'car-wash',
      vehicleIds: [vehicleId],
    );
    expect(failureError(missing), BookingFailure.washRequired);

    final updated = successValue(
      await harness.changeAppointment.call(
        userId: 'alex',
        appointmentId: booked.id,
        slotId: booked.slotId,
        serviceId: 'car-wash',
        vehicleIds: [vehicleId],
        washId: 'wash-quick',
      ),
    );
    expect(updated.washName, 'Quick wash');
    expect(updated.priceCents, 15000);
    expect(updated.id, booked.id);
    expect(
      (await harness.scheduling.findSlot(
        'car-wash-maegans-rides-$day-1100',
      ))!.bookedCount,
      0,
    );
  });

  test('the same wash is charged once for every vehicle', () async {
    final harness = AppHarness();
    final city = await harness.ensureVehicle('alex', name: 'City run');
    final weekend = await harness.ensureVehicle(
      'alex',
      name: 'Weekend',
      type: VehicleType.suv,
    );
    const day = '20261006';

    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: 'car-wash-maegans-rides-$day-0900',
        serviceId: 'car-wash',
        vehicleIds: [city, weekend],
        washId: 'wash-quick',
      ),
    );

    expect(booked.priceCents, 30000);
    expect(booked.washName, 'Quick wash');
    expect(booked.duration, const Duration(hours: 1));
    expect(booked.vehicleWashes, {city: 'wash-quick', weekend: 'wash-quick'});
  });

  test('each vehicle can take a different wash', () async {
    final harness = AppHarness();
    final city = await harness.ensureVehicle('alex', name: 'City run');
    final weekend = await harness.ensureVehicle(
      'alex',
      name: 'Weekend',
      type: VehicleType.suv,
    );
    const day = '20261006';

    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: 'car-wash-maegans-rides-$day-0900',
        serviceId: 'car-wash',
        vehicleIds: [city, weekend],
        vehicleWashes: {city: 'wash-quick', weekend: 'wash-full'},
      ),
    );

    expect(booked.priceCents, 43000);
    expect(booked.washName, 'Quick wash, Full wash');
    expect(booked.duration, const Duration(hours: 2));
    expect(booked.washId, isNull);
    expect(
      (await harness.scheduling.findSlot(
        'car-wash-maegans-rides-$day-1000',
      ))!.bookedCount,
      1,
    );
  });
}

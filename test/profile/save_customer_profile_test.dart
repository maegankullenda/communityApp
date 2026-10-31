import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/profile/domain/car_wash_pricing.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/save_customer_profile.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test(
    'a customer can save a name, address, phone number, and vehicles',
    () async {
      final harness = AppHarness();

      final profile = successValue(
        await harness.saveProfile.call(
          accountId: 'alex',
          firstName: '  Alex  ',
          surname: '  Nkosi  ',
          address: '  14 Oak Street  ',
          contactNumber: ' 082 123 4567 ',
          vehicles: const [
            VehicleInput(name: 'City run', type: VehicleType.hatch),
            VehicleInput(name: 'Family', type: VehicleType.suv),
          ],
        ),
      );

      expect(profile.firstName, 'Alex');
      expect(profile.surname, 'Nkosi');
      expect(profile.address, '14 Oak Street');
      expect(profile.contactNumber, '082 123 4567');
      expect(profile.vehicles.map((vehicle) => vehicle.name), [
        'City run',
        'Family',
      ]);
      expect(profile.vehicles.map((vehicle) => vehicle.type), [
        VehicleType.hatch,
        VehicleType.suv,
      ]);
    },
  );

  test(
    'an invalid contact number leaves the saved profile unchanged',
    () async {
      final harness = AppHarness();
      successValue(
        await harness.saveProfile.call(
          accountId: 'alex',
          address: '14 Oak Street',
          contactNumber: '0821234567',
          vehicles: const [],
        ),
      );

      final result = await harness.saveProfile.call(
        accountId: 'alex',
        address: '99 New Road',
        contactNumber: 'call me',
        vehicles: const [],
      );

      expect(failureError(result), ProfileFailure.invalidContactNumber);
      final stored = await harness.profiles.find('alex');
      expect(stored.address, '14 Oak Street');
      expect(stored.contactNumber, '0821234567');
    },
  );

  test('a customer can keep five vehicles and no more', () async {
    final harness = AppHarness();
    final five = [
      for (var index = 0; index < maxVehicles; index++)
        VehicleInput(name: 'Car $index', type: VehicleType.sedan),
    ];
    final saved = successValue(
      await harness.saveProfile.call(
        accountId: 'alex',
        address: '',
        contactNumber: '',
        vehicles: five,
      ),
    );
    expect(saved.vehicles, hasLength(5));

    final sixth = await harness.saveProfile.call(
      accountId: 'alex',
      address: '',
      contactNumber: '',
      vehicles: [
        ...five,
        const VehicleInput(name: 'Extra', type: VehicleType.hatch),
      ],
    );

    expect(failureError(sixth), ProfileFailure.tooManyVehicles);
    expect((await harness.profiles.find('alex')).vehicles, hasLength(5));
  });

  test('a blank vehicle name is rejected', () async {
    final harness = AppHarness();

    final result = await harness.saveProfile.call(
      accountId: 'alex',
      address: '',
      contactNumber: '',
      vehicles: const [VehicleInput(name: '   ', type: VehicleType.hatch)],
    );

    expect(failureError(result), ProfileFailure.emptyVehicleName);
    expect((await harness.profiles.find('alex')).vehicles, isEmpty);
  });

  test('editing a vehicle keeps its id and can change the type', () async {
    final harness = AppHarness();
    final created = successValue(
      await harness.saveProfile.call(
        accountId: 'alex',
        address: '14 Oak Street',
        contactNumber: '0821234567',
        vehicles: const [
          VehicleInput(name: 'City run', type: VehicleType.hatch),
        ],
      ),
    );

    final updated = successValue(
      await harness.saveProfile.call(
        accountId: 'alex',
        address: '14 Oak Street',
        contactNumber: '0821234567',
        vehicles: [
          VehicleInput(
            id: created.vehicles.single.id,
            name: 'City run',
            type: VehicleType.suv,
            registration: 'CA 123-456',
          ),
        ],
      ),
    );

    expect(updated.vehicles.single.id, created.vehicles.single.id);
    expect(updated.vehicles.single.type, VehicleType.suv);
    expect(updated.vehicles.single.registration, 'CA 123-456');
  });

  test(
    'a car wash price is taken from the vehicle and kept on the booking',
    () async {
      final harness = AppHarness();
      final slots = await harness.scheduling.slotsFor(
        serviceId: 'car-wash',
        providerId: 'sam-shine',
        rangeStart: DateTime(2026, 10, 6),
        rangeEnd: DateTime(2026, 10, 7),
      );
      final created = successValue(
        await harness.saveProfile.call(
          accountId: 'alex',
          address: '14 Oak Street',
          contactNumber: '0821234567',
          vehicles: const [
            VehicleInput(name: 'Family', type: VehicleType.sedan),
          ],
        ),
      );

      final booked = successValue(
        await harness.bookAppointment.call(
          userId: 'alex',
          slotId: slots.first.id,
          serviceId: 'car-wash',
          vehicleIds: [created.vehicles.single.id],
        ),
      );

      expect(booked.priceCents, carWashPriceCents(VehicleType.sedan));
      expect(booked.vehicleLabel, 'Family (Sedan)');

      successValue(
        await harness.saveProfile.call(
          accountId: 'alex',
          address: '14 Oak Street',
          contactNumber: '0821234567',
          vehicles: [
            VehicleInput(
              id: created.vehicles.single.id,
              name: 'Family',
              type: VehicleType.suv,
            ),
          ],
        ),
      );

      final stored = await harness.scheduling.appointmentsForUser('alex');
      expect(stored.single.priceCents, carWashPriceCents(VehicleType.sedan));
      expect(stored.single.vehicleLabel, 'Family (Sedan)');
    },
  );

  test('a car wash without a saved vehicle does not take the slot', () async {
    final harness = AppHarness();
    final slots = await harness.scheduling.slotsFor(
      serviceId: 'car-wash',
      providerId: 'maegans-rides',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );

    final missing = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: slots.first.id,
      serviceId: 'car-wash',
    );
    expect(failureError(missing), BookingFailure.vehicleRequired);

    final unknown = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: slots.first.id,
      serviceId: 'car-wash',
      vehicleIds: const ['not-mine'],
    );
    expect(failureError(unknown), BookingFailure.unknownVehicle);
    expect((await harness.scheduling.findSlot(slots.first.id))!.bookedCount, 0);
  });
}

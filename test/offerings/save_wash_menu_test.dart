import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/offerings/domain/save_wash_menu.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('a provider can change the price and duration of a wash', () async {
    final harness = AppHarness();

    final saved = successValue(
      await harness.saveWashMenu.call(
        providerId: 'maegans-rides',
        serviceId: 'car-wash',
        washes: const [
          WashDraft(
            id: 'wash-quick',
            name: 'Quick wash',
            durationHours: 2,
            priceCents: 18000,
            description: 'Exterior wash and tyre polish',
          ),
          WashDraft(
            id: 'wash-full',
            name: 'Full wash',
            durationHours: 3,
            priceCents: 32000,
          ),
          WashDraft(name: 'Interior only', durationHours: 1, priceCents: 9000),
        ],
      ),
    );

    expect(saved[0].id, 'wash-quick');
    expect(saved[0].duration.inHours, 2);
    expect(saved[0].priceCents, 18000);
    expect(saved[0].rateFor(VehicleType.suv).priceCents, 18000);
    expect(saved[0].description, 'Exterior wash and tyre polish');
    expect(saved[2].name, 'Interior only');
    expect(saved[2].id, isNot('wash-wax'));

    final stored = await harness.washes.washesFor(
      providerId: 'maegans-rides',
      serviceId: 'car-wash',
    );
    expect(stored.map((wash) => wash.name), [
      'Quick wash',
      'Full wash',
      'Interior only',
    ]);
  });

  test(
    'a wash needs a name, a 1 to 4 hour duration, and a rand price',
    () async {
      final harness = AppHarness();

      expect(
        failureError(
          await harness.saveWashMenu.call(
            providerId: 'maegans-rides',
            serviceId: 'car-wash',
            washes: const [
              WashDraft(name: ' ', durationHours: 1, priceCents: 1000),
            ],
          ),
        ),
        WashMenuFailure.emptyName,
      );
      expect(
        failureError(
          await harness.saveWashMenu.call(
            providerId: 'maegans-rides',
            serviceId: 'car-wash',
            washes: const [
              WashDraft(name: 'Quick wash', durationHours: 5, priceCents: 1000),
            ],
          ),
        ),
        WashMenuFailure.invalidDuration,
      );
      expect(
        failureError(
          await harness.saveWashMenu.call(
            providerId: 'maegans-rides',
            serviceId: 'car-wash',
            washes: const [
              WashDraft(name: 'Quick wash', durationHours: 1, priceCents: 0),
            ],
          ),
        ),
        WashMenuFailure.invalidPrice,
      );
    },
  );

  test('each vehicle type can have its own price and duration', () async {
    final harness = AppHarness();

    final saved = successValue(
      await harness.saveWashMenu.call(
        providerId: 'maegans-rides',
        serviceId: 'car-wash',
        washes: const [
          WashDraft(
            id: 'wash-quick',
            name: 'Quick wash',
            durationHours: 1,
            priceCents: 15000,
            rates: {
              VehicleType.hatch: VehicleRateDraft(
                durationHours: 1,
                priceCents: 15000,
              ),
              VehicleType.sedan: VehicleRateDraft(
                durationHours: 1,
                priceCents: 19000,
              ),
              VehicleType.suv: VehicleRateDraft(
                durationHours: 2,
                priceCents: 23000,
              ),
            },
          ),
        ],
      ),
    );

    expect(saved.single.rateFor(VehicleType.sedan).priceCents, 19000);
    expect(saved.single.rateFor(VehicleType.suv).duration.inHours, 2);

    final sedan = await harness.ensureVehicle(
      'alex',
      name: 'Weekday',
      type: VehicleType.sedan,
    );
    final suv = await harness.ensureVehicle(
      'alex',
      name: 'Weekend',
      type: VehicleType.suv,
    );
    final booked = successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: 'car-wash-maegans-rides-20261006-0900',
        serviceId: 'car-wash',
        vehicleIds: [sedan, suv],
        washId: 'wash-quick',
      ),
    );

    expect(booked.priceCents, 42000);
    expect(booked.duration, const Duration(hours: 2));
  });
}

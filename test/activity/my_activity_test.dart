import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/ordering/domain/place_order.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('a customer sees appointments and meal orders together', () async {
    final harness = AppHarness();
    final slots = await harness.scheduling.slotsFor(
      serviceId: 'beauty',
      providerId: 'riley-studio',
      rangeStart: DateTime(2026, 10, 6),
      rangeEnd: DateTime(2026, 10, 7),
    );
    successValue(
      await harness.bookAppointment.call(
        userId: 'alex',
        slotId: slots.first.id,
        serviceId: 'beauty',
      ),
    );
    successValue(
      await harness.placeOrder.call(
        userId: 'alex',
        serviceId: 'foodie',
        lines: const [OrderRequestLine(itemId: 'veggie-wrap', quantity: 1)],
      ),
    );

    final activity = await harness.loadMyActivity.call('alex');

    expect(activity.appointments.single.serviceName, 'Beauty');
    expect(activity.appointments.single.providerName, 'Riley Studio');
    expect(activity.orders.single.serviceName, 'Foodie');
    expect(activity.orders.single.providerName, "Jess's Kitchen");
    expect(
      activity.orders.single.order.lines.single.name,
      'Market veggie wrap',
    );
  });

  test('another customer does not see those bookings', () async {
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

    final activity = await harness.loadMyActivity.call('jess');

    expect(activity.appointments, isEmpty);
    expect(activity.orders, isEmpty);
  });
}

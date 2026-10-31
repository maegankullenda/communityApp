import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('an inactive service is hidden and cannot take a new booking', () async {
    final harness = AppHarness();
    final maegan = (await harness.catalog.findProvider('maegans-rides'))!;
    await harness.catalog.saveProvider(
      maegan.withServiceActive('car-wash', false),
    );

    final hidden = await harness.catalog.providersFor('car-wash');
    expect(hidden.map((provider) => provider.id), isNot(contains('maegans-rides')));
    expect(hidden.map((provider) => provider.id), contains('sam-shine'));

    final vehicleId = await harness.ensureVehicle('alex');
    final refused = await harness.bookAppointment.call(
      userId: 'alex',
      slotId: 'car-wash-maegans-rides-20261006-1300',
      serviceId: 'car-wash',
      vehicleIds: [vehicleId],
      washId: 'wash-quick',
    );
    expect(failureError(refused), BookingFailure.serviceUnavailable);

    final stored = (await harness.catalog.findProvider('maegans-rides'))!;
    await harness.catalog.saveProvider(
      stored.withServiceActive('car-wash', true),
    );
    final shown = await harness.catalog.providersFor('car-wash');
    expect(shown.map((provider) => provider.id), contains('maegans-rides'));
  });
}

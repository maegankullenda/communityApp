import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/register_service.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('a provider can register a new kind of service', () async {
    final harness = AppHarness();

    final service = successValue(
      await harness.registerService.call(
        providerId: 'sam-shine',
        name: '  Dog walking  ',
        summary: ' A neighbourhood walk ',
        fulfillment: FulfillmentKind.appointment,
      ),
    );

    expect(service.id, 'dog-walking');
    expect(service.name, 'Dog walking');
    expect(service.summary, 'A neighbourhood walk');

    final listed = await harness.catalog.listServices();
    expect(listed.map((item) => item.id), contains('dog-walking'));
    final providers = await harness.catalog.providersFor('dog-walking');
    expect(providers.single.id, 'sam-shine');
  });

  test('a blank name is rejected', () async {
    final harness = AppHarness();

    final result = await harness.registerService.call(
      providerId: 'sam-shine',
      name: '   ',
      summary: 'Nothing',
      fulfillment: FulfillmentKind.appointment,
    );

    expect(failureError(result), RegisterServiceFailure.emptyName);
  });

  test('a name with no letters is rejected', () async {
    final harness = AppHarness();

    final result = await harness.registerService.call(
      providerId: 'sam-shine',
      name: '!!!',
      summary: 'Nothing',
      fulfillment: FulfillmentKind.appointment,
    );

    expect(failureError(result), RegisterServiceFailure.emptyName);
    expect((await harness.catalog.listServices()).length, 3);
  });

  test('the same service name cannot be registered twice', () async {
    final harness = AppHarness();

    final result = await harness.registerService.call(
      providerId: 'riley-studio',
      name: 'Car wash',
      summary: 'Another wash',
      fulfillment: FulfillmentKind.appointment,
    );

    expect(failureError(result), RegisterServiceFailure.duplicateName);
  });

  test('an unknown provider cannot register a service', () async {
    final harness = AppHarness();

    final result = await harness.registerService.call(
      providerId: 'missing',
      name: 'Dog walking',
      summary: 'Walks',
      fulfillment: FulfillmentKind.appointment,
    );

    expect(failureError(result), RegisterServiceFailure.unknownProvider);
    expect((await harness.catalog.listServices()).length, 3);
  });
}

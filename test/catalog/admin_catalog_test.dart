import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/create_category.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('an admin category is not attached to a provider', () async {
    final harness = AppHarness();
    final created = successValue(
      await CreateCategory(harness.catalog).call(
        name: 'Dog walking',
        summary: 'A neighbourhood walk',
        fulfillment: FulfillmentKind.appointment,
      ),
    );

    expect(created.id, 'dog-walking');
    expect(created.active, isTrue);
    expect(await harness.catalog.providersFor('dog-walking'), isEmpty);
    expect(
      (await harness.catalog.listServices()).map((service) => service.name),
      contains('Dog walking'),
    );
  });

  test('a blank or duplicate category name is rejected', () async {
    final harness = AppHarness();
    final create = CreateCategory(harness.catalog);

    expect(
      failureError(
        await create.call(
          name: '   ',
          summary: 'Nothing',
          fulfillment: FulfillmentKind.appointment,
        ),
      ),
      CreateCategoryFailure.emptyName,
    );
    expect(
      failureError(
        await create.call(
          name: 'Car wash',
          summary: 'Another wash',
          fulfillment: FulfillmentKind.appointment,
        ),
      ),
      CreateCategoryFailure.duplicateName,
    );
  });

  test('a suspended provider is hidden from customers', () async {
    final harness = AppHarness();
    final sam = (await harness.catalog.findProvider('sam-shine'))!;

    await harness.catalog.saveProvider(sam.withActive(false));

    final providers = await harness.catalog.providersFor('car-wash');
    expect(
      providers.map((provider) => provider.id),
      isNot(contains('sam-shine')),
    );
    expect(providers.map((provider) => provider.id), contains('maegans-rides'));
  });
}

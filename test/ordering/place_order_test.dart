import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';
import 'package:community_app/features/ordering/domain/place_order.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('a customer can order meals that are on the menu this week', () async {
    final harness = AppHarness();

    final order = successValue(
      await harness.placeOrder.call(
        userId: 'alex',
        serviceId: 'foodie',
        lines: const [
          OrderRequestLine(itemId: 'lentil-stew', quantity: 2),
          OrderRequestLine(itemId: 'chicken-bowl', quantity: 1),
        ],
      ),
    );

    expect(order.providerId, 'jess-kitchen');
    expect(order.totalCents, 8500 * 2 + 9200);
    expect(order.lines.map((line) => line.name), [
      'Lentil stew',
      'Herb chicken bowl',
    ]);
  });

  test('the order keeps the price from the moment it was placed', () async {
    final harness = AppHarness();
    final order = successValue(
      await harness.placeOrder.call(
        userId: 'alex',
        serviceId: 'foodie',
        lines: const [OrderRequestLine(itemId: 'lentil-stew', quantity: 1)],
      ),
    );

    final current = (await harness.ordering.findItem('lentil-stew'))!;
    await harness.ordering.publishItem(
      MenuItem(
        id: current.id,
        providerId: current.providerId,
        serviceId: current.serviceId,
        name: current.name,
        description: current.description,
        priceCents: 12000,
        availableFrom: current.availableFrom,
        availableUntil: current.availableUntil,
      ),
    );

    final stored = await harness.ordering.ordersForUser('alex');
    expect(
      stored.single.lines.single.unitPriceCents,
      order.lines.single.unitPriceCents,
    );
    expect(stored.single.totalCents, 8500);
  });

  test('an empty order is rejected', () async {
    final harness = AppHarness();

    final result = await harness.placeOrder.call(
      userId: 'alex',
      serviceId: 'foodie',
      lines: const [],
    );

    expect(failureError(result), OrderFailure.emptyOrder);
    expect(await harness.ordering.ordersForUser('alex'), isEmpty);
  });

  test('a quantity of zero is rejected', () async {
    final harness = AppHarness();

    final result = await harness.placeOrder.call(
      userId: 'alex',
      serviceId: 'foodie',
      lines: const [OrderRequestLine(itemId: 'lentil-stew', quantity: 0)],
    );

    expect(failureError(result), OrderFailure.invalidQuantity);
  });

  test('an unknown meal is rejected', () async {
    final harness = AppHarness();

    final result = await harness.placeOrder.call(
      userId: 'alex',
      serviceId: 'foodie',
      lines: const [OrderRequestLine(itemId: 'missing', quantity: 1)],
    );

    expect(failureError(result), OrderFailure.unknownItem);
  });

  test('a meal cannot be ordered outside its available days', () async {
    final harness = AppHarness();
    harness.clock.instant = DateTime(2026, 10, 20, 8);

    final result = await harness.placeOrder.call(
      userId: 'alex',
      serviceId: 'foodie',
      lines: const [OrderRequestLine(itemId: 'lentil-stew', quantity: 1)],
    );

    expect(failureError(result), OrderFailure.itemUnavailable);
    expect(await harness.ordering.ordersForUser('alex'), isEmpty);
  });

  test('one order cannot mix cooks', () async {
    final harness = AppHarness();
    await harness.ordering.publishItem(
      MenuItem(
        id: 'garage-coffee',
        providerId: 'sam-shine',
        serviceId: 'foodie',
        name: 'Garage coffee',
        description: 'A flask for the wait.',
        priceCents: 300,
        availableFrom: DateTime(2026, 10, 1),
        availableUntil: DateTime(2026, 10, 30),
      ),
    );

    final result = await harness.placeOrder.call(
      userId: 'alex',
      serviceId: 'foodie',
      lines: const [
        OrderRequestLine(itemId: 'lentil-stew', quantity: 1),
        OrderRequestLine(itemId: 'garage-coffee', quantity: 1),
      ],
    );

    expect(failureError(result), OrderFailure.mixedProviders);
    expect(await harness.ordering.ordersForUser('alex'), isEmpty);
  });

  test('a meal cannot be ordered through a different service', () async {
    final harness = AppHarness();

    final result = await harness.placeOrder.call(
      userId: 'alex',
      serviceId: 'beauty',
      lines: const [OrderRequestLine(itemId: 'lentil-stew', quantity: 1)],
    );

    expect(failureError(result), OrderFailure.serviceMismatch);
  });
}

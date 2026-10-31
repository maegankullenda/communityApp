import 'package:community_app/core/clock.dart';
import 'package:community_app/core/id_generator.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/features/ordering/domain/customer_order.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';

final class OrderRequestLine {
  const OrderRequestLine({required this.itemId, required this.quantity});

  final String itemId;
  final int quantity;
}

final class PlaceOrder {
  const PlaceOrder({
    required OrderingRepository ordering,
    required IdGenerator ids,
    required Clock clock,
  }) : _ordering = ordering,
       _ids = ids,
       _clock = clock;

  final OrderingRepository _ordering;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Result<CustomerOrder, OrderFailure>> call({
    required String userId,
    required String serviceId,
    required List<OrderRequestLine> lines,
  }) async {
    if (lines.isEmpty) {
      return const Err(OrderFailure.emptyOrder);
    }
    if (lines.any((line) => line.quantity <= 0)) {
      return const Err(OrderFailure.invalidQuantity);
    }

    final built = <OrderLine>[];
    String? providerId;
    for (final line in lines) {
      final item = await _ordering.findItem(line.itemId);
      if (item == null) {
        return const Err(OrderFailure.unknownItem);
      }
      if (item.serviceId != serviceId) {
        return const Err(OrderFailure.serviceMismatch);
      }
      if (!item.isAvailableAt(_clock.now())) {
        return const Err(OrderFailure.itemUnavailable);
      }
      if (providerId != null && providerId != item.providerId) {
        return const Err(OrderFailure.mixedProviders);
      }
      providerId = item.providerId;
      built.add(
        OrderLine(
          itemId: item.id,
          name: item.name,
          quantity: line.quantity,
          unitPriceCents: item.priceCents,
        ),
      );
    }

    final order = CustomerOrder(
      id: _ids.next('order'),
      userId: userId,
      providerId: providerId!,
      serviceId: serviceId,
      lines: List.unmodifiable(built),
      placedAt: _clock.now(),
    );
    await _ordering.saveOrder(order);
    return Success(order);
  }
}

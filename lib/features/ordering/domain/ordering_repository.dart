import 'package:community_app/features/ordering/domain/customer_order.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';

enum OrderFailure {
  emptyOrder,
  invalidQuantity,
  unknownItem,
  itemUnavailable,
  mixedProviders,
  serviceMismatch,
}

abstract interface class OrderingRepository {
  Future<MenuItem?> findItem(String id);

  Future<List<MenuItem>> itemsFor({
    required String serviceId,
    required String providerId,
  });

  Future<void> publishItem(MenuItem item);

  Future<void> saveOrder(CustomerOrder order);

  Future<List<CustomerOrder>> ordersForUser(String userId);
}

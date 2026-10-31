import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/ordering/domain/customer_order.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';

final class InMemoryOrderingRepository implements OrderingRepository {
  InMemoryOrderingRepository(this._store);

  final CommunityStore _store;

  @override
  Future<MenuItem?> findItem(String id) async => _store.menuItems[id];

  @override
  Future<List<MenuItem>> itemsFor({
    required String serviceId,
    required String providerId,
  }) async {
    final items =
        _store.menuItems.values
            .where(
              (item) =>
                  item.serviceId == serviceId && item.providerId == providerId,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  @override
  Future<void> publishItem(MenuItem item) async {
    _store.menuItems[item.id] = item;
  }

  @override
  Future<void> saveOrder(CustomerOrder order) async {
    _store.orders[order.id] = order;
  }

  @override
  Future<List<CustomerOrder>> ordersForUser(String userId) async {
    return _store.orders.values
        .where((order) => order.userId == userId)
        .toList();
  }
}

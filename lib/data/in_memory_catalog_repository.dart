import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';

final class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository(this._store);

  final CommunityStore _store;

  @override
  Future<List<CommunityService>> listServices() async {
    return _store.services.values.toList();
  }

  @override
  Future<CommunityService?> findService(String id) async => _store.services[id];

  @override
  Future<ServiceProvider?> findProvider(String id) async =>
      _store.providers[id];

  @override
  Future<List<ServiceProvider>> providersFor(String serviceId) async {
    return _store.providers.values
        .where((provider) => provider.isActive(serviceId))
        .toList();
  }

  @override
  Future<List<ServiceProvider>> listProviders() async {
    return _store.providers.values.toList();
  }

  @override
  Future<void> saveService(CommunityService service) async {
    _store.services[service.id] = service;
  }

  @override
  Future<void> saveProvider(ServiceProvider provider) async {
    final previous = _store.providers[provider.id];
    _store.providers[provider.id] = provider;
    if (previous == null) {
      return;
    }
    final removed = previous.serviceIds.difference(provider.serviceIds);
    for (final serviceId in removed) {
      final bookedSlotIds = {
        for (final appointment in _store.appointments.values)
          appointment.slotId,
      };
      _store.slots.removeWhere(
        (id, slot) =>
            slot.providerId == provider.id &&
            slot.serviceId == serviceId &&
            !bookedSlotIds.contains(id),
      );
      _store.offerings.remove(offeringKey(provider.id, serviceId));
      _store.treatments.removeWhere(
        (_, treatment) =>
            treatment.providerId == provider.id &&
            treatment.serviceId == serviceId,
      );
      final stillOffered = _store.providers.values.any(
        (item) => item.serviceIds.contains(serviceId),
      );
      if (!stillOffered) {
        _removeService(serviceId);
      }
    }
  }

  void _removeService(String serviceId) {
    _store.services.remove(serviceId);
    _store.slots.removeWhere((_, slot) => slot.serviceId == serviceId);
    _store.appointments.removeWhere(
      (_, appointment) => appointment.serviceId == serviceId,
    );
    _store.orders.removeWhere((_, order) => order.serviceId == serviceId);
    _store.menuItems.removeWhere((_, item) => item.serviceId == serviceId);
    _store.washes.removeWhere((_, wash) => wash.serviceId == serviceId);
    _store.offerings.removeWhere(
      (_, offering) => offering.serviceId == serviceId,
    );
    _store.treatments.removeWhere(
      (_, treatment) => treatment.serviceId == serviceId,
    );
  }
}

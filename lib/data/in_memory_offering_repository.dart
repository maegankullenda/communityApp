import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';

final class InMemoryOfferingRepository implements OfferingRepository {
  InMemoryOfferingRepository(this._store);

  final CommunityStore _store;

  @override
  Future<ServiceOffering?> find({
    required String providerId,
    required String serviceId,
  }) async {
    return _store.offerings[offeringKey(providerId, serviceId)];
  }

  @override
  Future<List<ServiceOffering>> forService(String serviceId) async {
    return _store.offerings.values
        .where((offering) => offering.serviceId == serviceId)
        .toList();
  }

  @override
  Future<void> save(ServiceOffering offering) async {
    _store.offerings[offeringKey(offering.providerId, offering.serviceId)] =
        offering;
  }

  @override
  Future<List<Treatment>> treatmentsFor({
    required String providerId,
    required String serviceId,
  }) async {
    return _store.treatments.values
        .where(
          (treatment) =>
              treatment.providerId == providerId &&
              treatment.serviceId == serviceId,
        )
        .toList();
  }

  @override
  Future<void> replaceTreatments({
    required String providerId,
    required String serviceId,
    required List<Treatment> treatments,
  }) async {
    final remove = [
      for (final treatment in _store.treatments.values)
        if (treatment.providerId == providerId &&
            treatment.serviceId == serviceId)
          treatment.id,
    ];
    for (final id in remove) {
      _store.treatments.remove(id);
    }
    for (final treatment in treatments) {
      _store.treatments[treatment.id] = treatment;
    }
  }
}

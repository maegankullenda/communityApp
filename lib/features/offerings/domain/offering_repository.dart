import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';

abstract interface class OfferingRepository {
  Future<ServiceOffering?> find({
    required String providerId,
    required String serviceId,
  });

  Future<List<ServiceOffering>> forService(String serviceId);

  Future<void> save(ServiceOffering offering);

  Future<List<Treatment>> treatmentsFor({
    required String providerId,
    required String serviceId,
  });

  Future<void> replaceTreatments({
    required String providerId,
    required String serviceId,
    required List<Treatment> treatments,
  });
}

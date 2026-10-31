import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';

abstract interface class CatalogRepository {
  Future<List<CommunityService>> listServices();

  Future<CommunityService?> findService(String id);

  Future<List<ServiceProvider>> providersFor(String serviceId);

  Future<List<ServiceProvider>> listProviders();

  Future<ServiceProvider?> findProvider(String id);

  Future<void> saveService(CommunityService service);

  Future<void> saveProvider(ServiceProvider provider);
}

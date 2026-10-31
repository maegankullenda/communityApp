import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';

enum RegisterServiceFailure { emptyName, duplicateName, unknownProvider }

final class RegisterService {
  const RegisterService(this._catalog);

  final CatalogRepository _catalog;

  Future<Result<CommunityService, RegisterServiceFailure>> call({
    required String providerId,
    required String name,
    required String summary,
    required FulfillmentKind fulfillment,
  }) async {
    final trimmedName = name.trim();
    final serviceId = slugForServiceName(trimmedName);
    if (serviceId == null) {
      return const Err(RegisterServiceFailure.emptyName);
    }

    final provider = await _catalog.findProvider(providerId);
    if (provider == null) {
      return const Err(RegisterServiceFailure.unknownProvider);
    }

    final existing = await _catalog.findService(serviceId);
    if (existing != null) {
      return const Err(RegisterServiceFailure.duplicateName);
    }

    final service = CommunityService(
      id: serviceId,
      name: trimmedName,
      summary: summary.trim(),
      fulfillment: fulfillment,
    );
    await _catalog.saveService(service);
    await _catalog.saveProvider(provider.withService(service.id));
    return Success(service);
  }
}

String? slugForServiceName(String name) {
  final slug = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) {
    return null;
  }
  return slug;
}

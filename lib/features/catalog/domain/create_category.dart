import 'package:community_app/core/result.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/register_service.dart';

enum CreateCategoryFailure { emptyName, duplicateName }

final class CreateCategory {
  const CreateCategory(this._catalog);

  final CatalogRepository _catalog;

  Future<Result<CommunityService, CreateCategoryFailure>> call({
    required String name,
    required String summary,
    required FulfillmentKind fulfillment,
  }) async {
    final trimmedName = name.trim();
    final serviceId = slugForServiceName(trimmedName);
    if (serviceId == null) {
      return const Err(CreateCategoryFailure.emptyName);
    }
    final existing = await _catalog.findService(serviceId);
    if (existing != null) {
      return const Err(CreateCategoryFailure.duplicateName);
    }
    final service = CommunityService(
      id: serviceId,
      name: trimmedName,
      summary: summary.trim(),
      fulfillment: fulfillment,
    );
    await _catalog.saveService(service);
    return Success(service);
  }
}

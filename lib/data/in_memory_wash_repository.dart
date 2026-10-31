import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/offerings/domain/wash_repository.dart';

final class InMemoryWashRepository implements WashRepository {
  InMemoryWashRepository(this._store);

  final CommunityStore _store;

  @override
  Future<List<WashOption>> washesFor({
    required String providerId,
    required String serviceId,
  }) async {
    return _store.washes.values
        .where(
          (wash) =>
              wash.providerId == providerId && wash.serviceId == serviceId,
        )
        .toList();
  }

  @override
  Future<void> replaceWashes({
    required String providerId,
    required String serviceId,
    required List<WashOption> washes,
  }) async {
    final remove = [
      for (final wash in _store.washes.values)
        if (wash.providerId == providerId && wash.serviceId == serviceId)
          wash.id,
    ];
    for (final id in remove) {
      _store.washes.remove(id);
    }
    for (final wash in washes) {
      _store.washes[wash.id] = wash;
    }
  }
}

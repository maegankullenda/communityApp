import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';

final class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository(this._store);

  final CommunityStore _store;

  @override
  Future<CustomerProfile> find(String accountId) async {
    return _store.profiles[accountId] ?? CustomerProfile.empty(accountId);
  }

  @override
  Future<void> save(CustomerProfile profile) async {
    _store.profiles[profile.accountId] = profile;
  }
}

import 'package:community_app/features/profile/domain/customer_profile.dart';

abstract interface class ProfileRepository {
  Future<CustomerProfile> find(String accountId);

  Future<void> save(CustomerProfile profile);
}

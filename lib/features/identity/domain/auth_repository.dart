import 'package:community_app/core/result.dart';
import 'package:community_app/features/identity/domain/account.dart';

enum AuthFailure { invalidCredentials, unavailable }

abstract interface class AuthRepository {
  Account? get currentAccount;

  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<Account?> findById(String id);

  Future<Account?> findByProviderId(String providerId);
}

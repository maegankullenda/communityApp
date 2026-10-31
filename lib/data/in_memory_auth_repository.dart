import 'package:community_app/core/result.dart';
import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';

final class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository(this._store);

  final CommunityStore _store;

  @override
  Account? get currentAccount => _store.session;

  @override
  Future<Account?> findById(String id) async => _store.accounts[id];

  @override
  Future<Account?> findByProviderId(String providerId) async {
    for (final account in _store.accounts.values) {
      if (account.providerId == providerId) {
        return account;
      }
    }
    return null;
  }

  @override
  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async {
    final account = _accountForEmail(email);
    final storedPassword = _store.passwordsByEmail[email];
    if (account == null || storedPassword != password) {
      return const Err(AuthFailure.invalidCredentials);
    }
    _store.session = account;
    return Success(account);
  }

  @override
  Future<void> signOut() async {
    _store.session = null;
  }

  Account? _accountForEmail(String email) {
    for (final account in _store.accounts.values) {
      if (account.email == email) {
        return account;
      }
    }
    return null;
  }
}

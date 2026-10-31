import 'package:community_app/core/result.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';

final class SignIn {
  const SignIn(this._auth);

  final AuthRepository _auth;

  Future<Result<Account, AuthFailure>> call({
    required String email,
    required String password,
  }) {
    return _auth.signIn(email: email.trim().toLowerCase(), password: password);
  }
}

final class SignOut {
  const SignOut(this._auth);

  final AuthRepository _auth;

  Future<void> call() => _auth.signOut();
}

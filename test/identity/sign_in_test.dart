import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';

import '../support/app_harness.dart';
import '../support/results.dart';

void main() {
  test('a customer can sign in with the email in any case', () async {
    final harness = AppHarness();

    final account = successValue(
      await harness.signIn.call(
        email: '  Alex@Community.app ',
        password: demoPassword,
      ),
    );

    expect(account.id, 'alex');
    expect(account.role, AccountRole.customer);
    expect(harness.auth.currentAccount?.id, 'alex');
  });

  test('a wrong password does not start a session', () async {
    final harness = AppHarness();

    final result = await harness.signIn.call(
      email: alexEmail,
      password: 'nope',
    );

    expect(failureError(result), AuthFailure.invalidCredentials);
    expect(harness.auth.currentAccount, isNull);
  });

  test('Jordan can sign in as a second customer', () async {
    final harness = AppHarness();

    final account = successValue(
      await harness.signIn.call(email: jordanEmail, password: demoPassword),
    );

    expect(account.id, 'jordan');
    expect(account.displayName, 'Jordan');
    expect(account.role, AccountRole.customer);
  });

  test('signing out clears the session', () async {
    final harness = AppHarness();
    await harness.signIn.call(email: samEmail, password: demoPassword);

    await harness.signOut.call();

    expect(harness.auth.currentAccount, isNull);
  });
}

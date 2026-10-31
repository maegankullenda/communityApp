import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/data/seed_community.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/messages.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;
  AccountRole _role = AccountRole.customer;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final failure = await ref
        .read(sessionProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _error = failure == null ? null : authFailureMessage(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text('Community', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Book local services and keep appointments and meal orders in one place.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            TextField(
              key: const Key('email-field'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('password-field'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('sign-in-error'),
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('sign-in-button'),
              onPressed: _submitting ? null : _submit,
              child: const Text('Sign in'),
            ),
            const SizedBox(height: 28),
            Text('Sign in as', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AccountRole>(
              segments: const [
                ButtonSegment(
                  value: AccountRole.customer,
                  label: Text('Customer'),
                ),
                ButtonSegment(
                  value: AccountRole.provider,
                  label: Text('Provider'),
                ),
                ButtonSegment(value: AccountRole.admin, label: Text('Admin')),
              ],
              selected: {_role},
              onSelectionChanged: (selection) {
                setState(() => _role = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text('Demo accounts', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Password for every demo account: $demoPassword. These accounts stay on this device.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final account in demoAccounts.where(
              (account) => account.role == _role,
            ))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: Key('demo-${account.email}'),
                  title: Text(account.label),
                  subtitle: Text('${account.email}\n${account.detail}'),
                  isThreeLine: true,
                  onTap: () {
                    setState(() {
                      _email.text = account.email;
                      _password.text = demoPassword;
                      _error = null;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

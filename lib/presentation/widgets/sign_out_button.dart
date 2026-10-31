import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/presentation/dependencies.dart';

class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('sign-out'),
      tooltip: 'Sign out',
      onPressed: () => ref.read(sessionProvider.notifier).signOut(),
      icon: const Icon(Icons.logout),
    );
  }
}

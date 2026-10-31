import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/presentation/app_router.dart';
import 'package:community_app/presentation/theme.dart';

class CommunityApp extends ConsumerWidget {
  const CommunityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Community',
      theme: buildCommunityTheme(),
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/app.dart';
import 'package:community_app/core/clock.dart';
import 'package:community_app/data/seed_community.dart';
import 'package:community_app/presentation/dependencies.dart';

Future<void> pumpCommunity(
  WidgetTester tester, {
  DateTime? now,
  DateTime? seededAt,
}) async {
  final instant = now ?? DateTime(2026, 10, 5, 8);
  final seedInstant = seededAt ?? instant;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityStoreProvider.overrideWithValue(
          seedCommunity(now: seedInstant),
        ),
        clockProvider.overrideWithValue(FixedClock(instant)),
      ],
      child: const CommunityApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> signInAs(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const Key('email-field')), email);
  await tester.enterText(find.byKey(const Key('password-field')), demoPassword);
  await tester.tap(find.byKey(const Key('sign-in-button')));
  await tester.pumpAndSettle();
}

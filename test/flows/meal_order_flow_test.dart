import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a customer orders a meal and sees it with their bookings', (
    tester,
  ) async {
    await pumpCommunity(tester);
    await signInAs(tester, alexEmail);

    await tester.tap(find.byKey(const ValueKey('open-service-foodie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-jess-kitchen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item-lentil-stew-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-order')));
    await tester.pumpAndSettle();

    expect(find.text('1 x Lentil stew'), findsOneWidget);
    expect(find.text('Total 85.00'), findsOneWidget);
    expect(find.text("Jess's Kitchen"), findsOneWidget);
  });
}

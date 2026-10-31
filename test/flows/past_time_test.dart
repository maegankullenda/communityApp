import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a customer cannot book a time that has already passed', (
    tester,
  ) async {
    await pumpCommunity(
      tester,
      now: DateTime(2026, 10, 6, 10),
      seededAt: DateTime(2026, 10, 5, 8),
    );
    tester.view.physicalSize = const Size(390, 1400);
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);

    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-sam-shine')));
    await tester.pumpAndSettle();

    expect(find.text('09:00'), findsNothing);
    expect(find.text('09:00 Passed'), findsNothing);
    expect(find.text('08:00'), findsNothing);
    expect(find.text('12:00', skipOffstage: false), findsOneWidget);
    expect(find.text('14:00', skipOffstage: false), findsOneWidget);
    expect(find.text('16:00', skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '11:00'))
          .onSelected,
      isNotNull,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-service-beauty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-riley-studio')));
    await tester.pumpAndSettle();

    expect(find.text('09:00'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '11:00'))
          .onSelected,
      isNotNull,
    );
  });
}

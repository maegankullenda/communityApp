import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';
import 'package:community_app/presentation/day_tabs.dart';

import '../support/pump_app.dart';

Future<void> _scrollToDay(WidgetTester tester, String key) async {
  final scrollable = find.descendant(
    of: find.byType(DayTabs),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    80,
    scrollable: scrollable,
  );
  await tester.drag(scrollable, const Offset(-120, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('car wash times run from 08:00 to 16:00 for the next week', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 1400);
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);

    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-sam-shine')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('day-2026-10-5')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('day-2026-10-6')));
    await tester.pumpAndSettle();
    expect(find.text('08:00', skipOffstage: false), findsOneWidget);
    expect(find.text('16:00', skipOffstage: false), findsOneWidget);
    await _scrollToDay(tester, 'day-2026-10-11');
    await tester.tap(find.byKey(const ValueKey('day-2026-10-11')));
    await tester.pumpAndSettle();
    expect(find.text('08:00', skipOffstage: false), findsOneWidget);
    expect(find.text('16:00', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a foodie menu can be viewed for each day of the next week', (
    tester,
  ) async {
    await pumpCommunity(tester);
    await signInAs(tester, alexEmail);

    await tester.tap(find.byKey(const ValueKey('open-service-foodie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-jess-kitchen')));
    await tester.pumpAndSettle();

    expect(find.text('Lentil stew'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-2026-10-5')), findsOneWidget);
    await _scrollToDay(tester, 'day-2026-10-11');
    await tester.tap(find.byKey(const ValueKey('day-2026-10-11')));
    await tester.pumpAndSettle();
    expect(find.text('Lentil stew'), findsOneWidget);
    expect(find.text('Market veggie wrap'), findsOneWidget);
  });
}

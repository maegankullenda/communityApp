import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a booked day opens with its vehicle, time, and wash selected', (
    tester,
  ) async {
    await pumpCommunity(tester);
    await signInAs(tester, alexEmail);
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-vehicle-name')),
      'City run',
    );
    await tester.tap(find.byKey(const Key('add-vehicle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-maegans-rides')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('book-wash-City run-Quick wash')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-maegans-rides')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-2026-10-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('book-wash-City run-Full wash')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-maegans-rides')));
    await tester.pumpAndSettle();

    _expectBooking(tester, time: '09:00', wash: 'Quick wash', price: 'R150.00');

    await tester.tap(find.byKey(const ValueKey('day-2026-10-6')));
    await tester.pumpAndSettle();
    _expectBooking(tester, time: '11:00', wash: 'Full wash', price: 'R280.00');

    await tester.tap(find.byKey(const ValueKey('day-2026-10-5')));
    await tester.pumpAndSettle();
    _expectBooking(tester, time: '09:00', wash: 'Quick wash', price: 'R150.00');
  });
}

void _expectBooking(
  WidgetTester tester, {
  required String time,
  required String wash,
  required String price,
}) {
  expect(
    find.byKey(const ValueKey('book-vehicle-selected-City run')),
    findsOneWidget,
  );
  expect(
    find.byKey(ValueKey('book-wash-selected-City run-$wash')),
    findsOneWidget,
  );
  expect(
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '$time Booked'))
        .selected,
    isTrue,
  );
  expect(find.text('Update booking · $price'), findsOneWidget);
}

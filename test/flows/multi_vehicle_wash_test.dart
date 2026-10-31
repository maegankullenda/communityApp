import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a shared wash is charged for every vehicle in the booking', (
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
    await tester.enterText(
      find.byKey(const Key('new-vehicle-name')),
      'Weekend',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('vehicle-type-suv')));
    await tester.tap(find.byKey(const ValueKey('vehicle-type-suv')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-vehicle')));
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
    await tester.tap(find.byKey(const ValueKey('book-vehicle-Weekend')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('book-wash-City run-Quick wash')),
    );
    await tester.tap(
      find.byKey(const ValueKey('book-wash-Weekend-Quick wash')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Book this time · R300.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.text('Quick wash'), findsOneWidget);
    expect(find.text('R300.00'), findsOneWidget);
    expect(find.text('City run (Hatch), Weekend (SUV)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-maegans-rides')));
    await tester.pumpAndSettle();
    expect(find.text('Update booking · R300.00'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('book-wash-selected-City run-Quick wash')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('book-wash-selected-Weekend-Quick wash')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('book-wash-Weekend-Full wash')));
    await tester.pumpAndSettle();
    expect(find.text('Update booking · R430.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.text('Quick wash, Full wash'), findsOneWidget);
    expect(find.text('R430.00'), findsOneWidget);
  });
}

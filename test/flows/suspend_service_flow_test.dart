import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('Maegan can suspend her car wash so Alex cannot book it', (
    tester,
  ) async {
    await pumpCommunity(tester);
    await signInAs(tester, maeganEmail);

    expect(find.text('Edit service'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('service-active-car-wash')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('service-active-car-wash')));
    await tester.pumpAndSettle();
    expect(find.text('Suspended. Customers cannot book this.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);
    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();

    expect(find.text("Sam's Shine"), findsOneWidget);
    expect(find.text("Maegan's Rides"), findsNothing);
  });

  testWidgets('Maegan deletes a suspended service only after confirming', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();
    await signInAs(tester, maeganEmail);

    expect(find.text('Delete service'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('service-active-car-wash')));
    await tester.pumpAndSettle();
    expect(find.text('Delete service'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-service-car-wash')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this service?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('keep-service')));
    await tester.pumpAndSettle();
    expect(find.text('Car wash'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-service')));
    await tester.pumpAndSettle();

    expect(find.text('You have not published a service yet.'), findsOneWidget);
    expect(find.text('Car wash'), findsNothing);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);
    expect(find.text('Car wash'), findsOneWidget);
  });

  testWidgets('a service only Maegan offered disappears for Alex', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 4000);
    await tester.pumpAndSettle();
    await signInAs(tester, maeganEmail);

    await tester.tap(find.byKey(const Key('offer-service-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('offer-category-beauty')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('continue-offer')));
    await tester.tap(find.byKey(const Key('continue-offer')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('offering-name-field')),
      'Maegan beauty parlor',
    );
    await tester.enterText(
      find.byKey(const Key('offering-description-field')),
      'Cuts and colour',
    );
    await tester.ensureVisible(find.byKey(const Key('open-days-weekdays')));
    await tester.tap(find.byKey(const Key('open-days-weekdays')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('weekday-hour-10')));
    await tester.tap(find.byKey(const ValueKey('weekday-hour-10')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('treatment-name-0')),
      'Cut and colour',
    );
    await tester.tap(find.byKey(const ValueKey('treatment-hours-0-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('treatment-price-0')),
      '200.00',
    );
    await tester.ensureVisible(find.byKey(const Key('save-offering')));
    await tester.tap(find.byKey(const Key('save-offering')));
    await tester.pumpAndSettle();

    final active = find.byKey(const ValueKey('service-active-beauty'));
    await tester.ensureVisible(active);
    await tester.pumpAndSettle();
    await tester.tap(active);
    await tester.pumpAndSettle();
    expect(find.text('Suspended. Customers cannot book this.'), findsOneWidget);
    final delete = find.byKey(const ValueKey('delete-service-beauty'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-service')));
    await tester.pumpAndSettle();

    expect(find.text('Beauty'), findsNothing);
    expect(find.text('Car wash'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);

    await tester.tap(find.byKey(const ValueKey('open-service-beauty')));
    await tester.pumpAndSettle();
    expect(find.text('Riley Studio'), findsOneWidget);
    expect(find.text('Maegan beauty parlor'), findsNothing);
  });
}

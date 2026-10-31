import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'a provider opens a confirmed booking and sees how to reach the customer',
    (tester) async {
      await pumpCommunity(tester);
      tester.view.physicalSize = const Size(390, 4000);
      await tester.pumpAndSettle();
      await signInAs(tester, alexEmail);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        'Alex',
      );
      await tester.enterText(
        find.byKey(const Key('profile-surname-field')),
        'Nkosi',
      );
      await tester.enterText(
        find.byKey(const Key('address-field')),
        '14 Oak Street',
      );
      await tester.enterText(
        find.byKey(const Key('contact-number-field')),
        '0821234567',
      );
      await tester.enterText(
        find.byKey(const Key('new-vehicle-name')),
        'City run',
      );
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
      await tester.tap(find.byKey(const ValueKey('provider-sam-shine')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('book-slot')));
      await tester.tap(find.byKey(const Key('book-slot')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      await signInAs(tester, samEmail);
      await tester.tap(find.byIcon(Icons.event_note_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('booked-booking-day-2026-10-5')),
      );
      await tester.tap(
        find.byKey(const ValueKey('booked-booking-day-2026-10-5')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer-first-name')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('customer-first-name'))).data,
        'Alex',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('customer-surname'))).data,
        'Nkosi',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('customer-contact-number')))
            .data,
        '0821234567',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('customer-address'))).data,
        '14 Oak Street',
      );
    },
  );
}

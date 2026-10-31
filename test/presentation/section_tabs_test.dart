import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'customers and providers open notifications from the bottom bar',
    (tester) async {
      await pumpCommunity(tester);
      await tester.pumpAndSettle();
      await signInAs(tester, alexEmail);

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notifications-empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      await signInAs(tester, samEmail);

      expect(find.text('Your work'), findsOneWidget);
      expect(find.byKey(const Key('booking-tab-calendar')), findsNothing);

      await tester.tap(find.byIcon(Icons.event_note_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Bookings'), findsWidgets);
      expect(find.byKey(const Key('booking-tab-calendar')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('Your profile'), findsOneWidget);
      expect(find.byKey(const Key('profile-contact-details')), findsOneWidget);
      expect(find.byKey(const Key('profile-vehicles')), findsNothing);
      expect(
        find.text('Save your name and how neighbours can reach you.'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    },
  );
}

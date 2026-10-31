import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

Future<void> _bookFacial(WidgetTester tester) async {
  await pumpCommunity(tester);
  tester.view.physicalSize = const Size(390, 4000);
  await tester.pumpAndSettle();
  await signInAs(tester, rileyEmail);

  await tester.tap(find.byKey(const ValueKey('edit-service-beauty')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('offering-name-field')),
    'Cookies hive',
  );
  await tester.enterText(
    find.byKey(const ValueKey('treatment-name-0')),
    'Facial',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('treatment-hours-0-1')));
  await tester.tap(find.byKey(const ValueKey('treatment-hours-0-1')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('treatment-price-0')),
    '200.00',
  );
  await tester.ensureVisible(find.byKey(const Key('auto-confirm-bookings')));
  await tester.tap(find.byKey(const Key('auto-confirm-bookings')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('save-offering')));
  await tester.tap(find.byKey(const Key('save-offering')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('sign-out')));
  await tester.pumpAndSettle();
  await signInAs(tester, alexEmail);
  await tester.tap(find.byKey(const ValueKey('open-service-beauty')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('provider-riley-studio')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('book-treatment-Facial')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('09:00'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('book-slot')));
  await tester.tap(find.byKey(const Key('book-slot')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('sign-out')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a pending booking notifies the provider and confirming notifies the customer',
    (tester) async {
      await _bookFacial(tester);
      await signInAs(tester, rileyEmail);

      expect(find.byKey(const Key('notification-count')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('notification-count')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(
        find.text('New Booking: Alex has requested a Facial.'),
        findsOneWidget,
      );

      await tester.tap(find.text('New Booking: Alex has requested a Facial.'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm booking'), findsOneWidget);

      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(
        find.text('New Booking: Alex has requested a Facial.'),
        findsNothing,
      );
      expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      await signInAs(tester, alexEmail);

      expect(find.byKey(const Key('notification-count')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Booking Confirmed: Cookies hive has confirmed your Facial appointment for Mon 5 Oct at 09:00',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('declining a booking notifies the customer', (tester) async {
    await _bookFacial(tester);
    await signInAs(tester, rileyEmail);
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Booking: Alex has requested a Facial.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('decline-message')),
      'That morning is full.',
    );
    await tester.tap(find.byKey(const Key('send-decline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text('New Booking: Alex has requested a Facial.'),
      findsNothing,
    );
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);
    expect(find.byKey(const Key('notification-count')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text('Booking declined: Cookies hive declined your Facial.'),
      findsOneWidget,
    );

    await tester.tap(
      find.text('Booking declined: Cookies hive declined your Facial.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('That morning is full.'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'turning auto confirm off leaves a booking pending until the provider confirms it',
    (tester) async {
      await pumpCommunity(tester);
      tester.view.physicalSize = const Size(390, 4000);
      await tester.pumpAndSettle();
      await signInAs(tester, rileyEmail);

      await tester.tap(find.byKey(const ValueKey('edit-service-beauty')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('treatment-name-0')),
        'Cut and colour',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('treatment-hours-0-1')),
      );
      await tester.tap(find.byKey(const ValueKey('treatment-hours-0-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('treatment-price-0')),
        '200.00',
      );
      await tester.ensureVisible(
        find.byKey(const Key('auto-confirm-bookings')),
      );
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
      await tester.tap(
        find.byKey(const ValueKey('book-treatment-Cut and colour')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('book-slot')));
      await tester.tap(find.byKey(const Key('book-slot')));
      await tester.pumpAndSettle();

      expect(find.text('Pending confirmation (1)'), findsOneWidget);
      expect(find.text('Pending confirmation'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        tester
            .widgetList<Text>(find.text('Pending confirmation'))
            .where((text) => text.style?.color == const Color(0xFFE65100)),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      await signInAs(tester, rileyEmail);
      await tester.tap(find.byIcon(Icons.event_note_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('booking-tab-awaiting')));
      await tester.tap(find.byKey(const Key('booking-tab-awaiting')));
      await tester.pumpAndSettle();

      expect(find.text('Awaiting confirmation'), findsWidgets);
      expect(find.text('Riley Studio'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Pending confirmation'), findsNothing);
      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Not added yet'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(
        find.text('No bookings are waiting for confirmation.'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booked-booking-day-2026-10-5')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      await signInAs(tester, alexEmail);
      await tester.tap(find.byIcon(Icons.event_note_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('booking-tab-confirmed')), findsOneWidget);
      expect(
        tester
            .widgetList<Text>(find.text('Confirmed'))
            .where((text) => text.style?.color == const Color(0xFF1F6B4A)),
        hasLength(1),
      );
    },
  );

  testWidgets('a declined booking shows the provider message to the customer', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 4000);
    await tester.pumpAndSettle();
    await signInAs(tester, rileyEmail);

    await tester.tap(find.byKey(const ValueKey('edit-service-beauty')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('treatment-name-0')),
      'Cut and colour',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('treatment-hours-0-1')),
    );
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
    await tester.tap(
      find.byKey(const ValueKey('book-treatment-Cut and colour')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('book-slot')));
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, rileyEmail);
    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('booking-tab-awaiting')));
    await tester.tap(find.byKey(const Key('booking-tab-awaiting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('decline-message')),
      'That morning is full. Try the following week.',
    );
    await tester.tap(find.byKey(const Key('send-decline')));
    await tester.pumpAndSettle();

    expect(
      find.text('No bookings are waiting for confirmation.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);
    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-tab-declined')), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Tap to read the provider\'s message.'));
    await tester.pumpAndSettle();

    expect(
      find.text('That morning is full. Try the following week.'),
      findsOneWidget,
    );
    expect(find.text('Suggested dates'), findsNothing);
    expect(find.text('Edit booking'), findsOneWidget);
    expect(find.text('Delete booking'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-declined-booking')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Update booking'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('That morning is full. Try the following week.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('delete-declined-booking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-booking')));
    await tester.pumpAndSettle();
    expect(find.text('Declined'), findsNothing);
    expect(find.textContaining('Nothing booked yet.'), findsOneWidget);
  });
}

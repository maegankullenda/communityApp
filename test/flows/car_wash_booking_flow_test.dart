import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a customer books a car wash and the provider sees it taken', (
    tester,
  ) async {
    await pumpCommunity(tester);
    await signInAs(tester, alexEmail);
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
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
    expect(find.text('14 Oak Street'), findsOneWidget);
    expect(find.text('City run'), findsWidgets);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Car wash'), findsOneWidget);
    expect(find.text('Foodie'), findsOneWidget);
    expect(find.text('Beauty'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    expect(find.text("Sam's Shine"), findsOneWidget);
    expect(
      find.text('Driveway and mobile washes, booked by the hour.'),
      findsOneWidget,
    );
    expect(find.text("Maegan's Rides"), findsOneWidget);
    expect(
      find.text('Exterior and interior washes, with a rinse while you wait.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('provider-sam-shine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('book-slot'))).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();
    expect(find.text('Choose which vehicle this wash is for.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('book-vehicle-selected-City run')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('book-vehicle-selected-City run')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
    await tester.tap(find.byKey(const ValueKey('book-vehicle-Weekend')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('book-vehicle-selected-City run')),
          )
          .color,
      const Color(0xFF1F6B4A),
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('book-vehicle-selected-Weekend')),
          )
          .color,
      const Color(0xFF1F6B4A),
    );
    expect(find.text('Book this time · 340.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.text('Your bookings'), findsOneWidget);
    expect(find.text("Sam's Shine"), findsOneWidget);
    expect(find.textContaining('at 09:00'), findsOneWidget);
    expect(find.text('City run (Hatch), Weekend (SUV)'), findsOneWidget);
    expect(find.text('340.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, samEmail);
    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('booked-booking-day-2026-10-5')),
    );
    await tester.tap(
      find.byKey(const ValueKey('booked-booking-day-2026-10-5')),
    );
    await tester.pumpAndSettle();

    expect(find.text("Sam's Shine"), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Car wash'), findsNothing);
    expect(find.textContaining('at 09:00'), findsOneWidget);
    expect(find.text('City run (Hatch), Weekend (SUV)'), findsOneWidget);
    expect(find.text('340.00'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);
    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-sam-shine')));
    await tester.pumpAndSettle();

    expect(find.text('Book for 09:00'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('book-vehicle-selected-City run')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('book-vehicle-selected-Weekend')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '09:00 Booked'))
          .selected,
      isTrue,
    );
    expect(find.text('Update booking · 340.00'), findsOneWidget);
    expect(find.text('Hatch · 120.00'), findsNothing);
    expect(find.text('SUV · 220.00'), findsNothing);
    expect(find.text('09:00 Booked'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('book-vehicle-Weekend')));
    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();
    expect(find.text('Update booking · 120.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.textContaining('at 11:00'), findsOneWidget);
    expect(find.textContaining('at 09:00'), findsNothing);
    expect(find.text('City run (Hatch)'), findsOneWidget);
  });
}

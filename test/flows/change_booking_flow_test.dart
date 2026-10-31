import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a customer can change and cancel a car wash booking', (
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
    await tester.tap(find.byKey(const ValueKey('provider-sam-shine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-2026-10-7')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '09:00'))
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('day-2026-10-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.textContaining('at 09:00'), findsOneWidget);
    await tester.tap(_keyed('edit-appointment-'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '09:00 Booked'))
          .selected,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('book-vehicle-selected-City run')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
    await tester.tap(find.byKey(const ValueKey('book-vehicle-Weekend')));
    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();
    expect(find.text('Update booking · 220.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.textContaining('at 11:00'), findsOneWidget);
    expect(find.text('Weekend (SUV)'), findsOneWidget);
    expect(find.text('220.00'), findsOneWidget);
    expect(find.textContaining('at 09:00'), findsNothing);

    await tester.tap(_keyed('edit-appointment-'));
    await tester.pumpAndSettle();
    expect(find.text('Updating…'), findsNothing);
    expect(find.textContaining('Update booking'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('book-slot'))).onPressed,
      isNotNull,
    );
    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();

    await tester.tap(_keyed('cancel-appointment-'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-booking')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing booked yet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Car wash'), findsOneWidget);
    expect(find.text('09:00'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-sam-shine')));
    await tester.pumpAndSettle();
    expect(find.text('09:00 Booked'), findsNothing);
    expect(find.text('11:00 Booked'), findsNothing);
  });
}

Finder _keyed(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
}

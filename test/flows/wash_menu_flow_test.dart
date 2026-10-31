import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('Maegan prices her washes and Alex can book and change one', (
    tester,
  ) async {
    await pumpCommunity(tester);
    await tester.pumpAndSettle();
    await signInAs(tester, maeganEmail);

    tester.view.physicalSize = const Size(390, 4000);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-service-car-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-washes')));
    await tester.pumpAndSettle();
    expect(find.text('Quick wash'), findsOneWidget);
    expect(find.text('Full wash'), findsOneWidget);
    expect(find.text('Wax and detailing'), findsOneWidget);
    expect(find.text('Hatch'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('expand-wash-0')));
    await tester.pumpAndSettle();
    expect(find.text('Hatch'), findsOneWidget);
    expect(find.text('Sedan'), findsOneWidget);
    expect(find.text('SUV'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('wash-description-0')))
          .controller
          ?.text,
      'Wash and wipe exterior and tyre polish',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wash-description-0')),
      'Exterior wash and tyre polish',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wash-price-0-hatch')),
      '180',
    );
    final saveWashes = find.byKey(const Key('save-washes'));
    final list = find.byKey(const Key('wash-menu-list'));
    for (
      var attempt = 0;
      attempt < 8 && saveWashes.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(saveWashes);
    await tester.pumpAndSettle();
    await tester.tap(saveWashes);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);

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

    expect(find.text('Duration: ~1h'), findsOneWidget);
    expect(find.text('Duration: ~2h'), findsOneWidget);
    expect(find.textContaining('R180.00'), findsNothing);
    expect(find.text('Exterior wash and tyre polish'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('wash-details-Full wash')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hatch'), findsNothing);
    expect(
      find.text(
        'Wash and wipe exterior, interior vacuum, dash shine and tyre polish',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('close-wash-details')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Wash and wipe exterior, interior vacuum, dash shine and tyre polish',
      ),
      findsNothing,
    );
    await tester.tap(find.text('09:00'));
    await tester.tap(find.byKey(const ValueKey('book-vehicle-City run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a wash for each vehicle.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('book-wash-City run-Quick wash')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Book this time · R180.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.text('Quick wash'), findsOneWidget);
    expect(find.text('R180.00'), findsOneWidget);

    await tester.tap(_keyed('edit-appointment-'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('book-wash-selected-City run-Quick wash')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('book-wash-City run-Full wash')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update booking · R280.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.text('Full wash'), findsOneWidget);
    expect(find.text('R280.00'), findsOneWidget);
    expect(find.text('Quick wash'), findsNothing);
  });
}

Finder _keyed(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
}

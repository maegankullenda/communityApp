import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('saving a profile shows a confirmation that then disappears', (
    tester,
  ) async {
    await pumpCommunity(tester);
    await signInAs(tester, alexEmail);
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name-field')), 'Alex');
    await tester.enterText(
      find.byKey(const Key('profile-surname-field')),
      'Nkosi',
    );
    await tester.enterText(
      find.byKey(const Key('address-field')),
      '12 Oak Street',
    );
    await tester.enterText(
      find.byKey(const Key('contact-number-field')),
      '082 123 4567',
    );
    await tester.enterText(
      find.byKey(const Key('new-vehicle-name')),
      'City run',
    );
    await tester.tap(find.byKey(const Key('add-vehicle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-profile')));
    await tester.tap(find.byKey(const Key('save-profile')));

    final saved = find.byKey(const Key('profile-saved'));
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (saved.evaluate().isNotEmpty) {
        break;
      }
    }

    expect(saved, findsOneWidget);
    expect(find.text('Your settings have been saved.'), findsOneWidget);
    expect(find.text('Alex'), findsWidgets);
    expect(find.text('Nkosi'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(saved, findsNothing);
  });
}

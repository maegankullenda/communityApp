import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('the login screen shows the demo accounts for the chosen role', (
    tester,
  ) async {
    await pumpCommunity(tester);

    expect(find.text('Alex, customer'), findsOneWidget);
    expect(find.text('Sam, car wash'), findsNothing);
    expect(find.text('Maegan, admin'), findsNothing);

    await tester.tap(find.text('Provider'));
    await tester.pumpAndSettle();
    expect(find.text('Alex, customer'), findsNothing);
    expect(find.text('Sam, car wash'), findsOneWidget);
    expect(
      find.text("Maegan, car wash", skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Sam, car wash'), findsNothing);
    expect(find.text('Maegan, admin'), findsOneWidget);
  });

  testWidgets('Maegan Admin can hide a category and suspend a provider', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();
    await signInAs(tester, maeganAdminEmail);

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('What services are you looking for'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category-active-beauty')));
    await tester.pumpAndSettle();
    expect(find.text('Hidden. Customers cannot browse this.'), findsOneWidget);

    final sam = find.byKey(const ValueKey('provider-active-sam-shine'));
    await tester.ensureVisible(sam);
    await tester.tap(sam);
    await tester.pumpAndSettle();
    expect(
      find.text('Suspended. Customers cannot book this provider.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);

    expect(find.text('Beauty'), findsNothing);
    expect(find.text('Car wash'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-service-car-wash')));
    await tester.pumpAndSettle();
    expect(find.text("Sam's Shine"), findsNothing);
    expect(find.text("Maegan's Rides"), findsOneWidget);
  });

  testWidgets('Maegan Admin can add a category customers can browse', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 1400);
    await tester.pumpAndSettle();
    await signInAs(tester, maeganAdminEmail);

    await tester.tap(find.byKey(const Key('add-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Dog walking',
    );
    await tester.enterText(
      find.byKey(const Key('category-summary-field')),
      'A neighbourhood walk',
    );
    await tester.tap(find.byKey(const Key('save-category')));
    await tester.pumpAndSettle();

    expect(find.text('Dog walking'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);

    expect(find.text('Dog walking'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-service-dog-walking')));
    await tester.pumpAndSettle();
    expect(find.text('Nobody is offering this yet.'), findsOneWidget);
  });
}

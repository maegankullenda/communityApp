import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/data/seed_community.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('Maegan can offer Beauty and Alex sees her under that service', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 4000);
    await tester.pumpAndSettle();
    await signInAs(tester, maeganEmail);

    await tester.tap(find.byKey(const Key('offer-service-button')));
    await tester.pumpAndSettle();
    expect(find.text('Car wash'), findsOneWidget);
    expect(find.text('Foodie'), findsOneWidget);
    expect(find.text('Beauty'), findsOneWidget);
    expect(find.byKey(const Key('service-name-field')), findsNothing);

    await offerBeautyParlor(tester);

    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Maegan beauty parlor'), findsOneWidget);
    expect(find.text('Car wash'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await signInAs(tester, alexEmail);

    await tester.tap(find.byKey(const ValueKey('open-service-beauty')));
    await tester.pumpAndSettle();

    expect(find.text('Riley Studio'), findsOneWidget);
    expect(find.text('Maegan beauty parlor'), findsOneWidget);
    expect(find.text("Maegan's Rides"), findsNothing);

    await tester.tap(find.byKey(const ValueKey('provider-maegans-rides')));
    await tester.pumpAndSettle();
    expect(find.text('Cuts and colour'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('book-treatment-Cut and colour')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();
    expect(find.text('Book this time · R200.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-slot')));
    await tester.pumpAndSettle();

    expect(find.text('Maegan beauty parlor'), findsOneWidget);
    expect(find.text('Cut and colour'), findsOneWidget);
    expect(find.text('R200.00'), findsOneWidget);
  });

  testWidgets('Maegan can edit the beauty service she already offers', (
    tester,
  ) async {
    await pumpCommunity(tester);
    tester.view.physicalSize = const Size(390, 4000);
    await tester.pumpAndSettle();
    await signInAs(tester, maeganEmail);

    await tester.tap(find.byKey(const Key('offer-service-button')));
    await tester.pumpAndSettle();
    await offerBeautyParlor(tester);

    await tester.tap(find.byKey(const ValueKey('edit-service-beauty')));
    await tester.pumpAndSettle();
    expect(find.text('Edit your service'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('offering-name-field')),
      'Cookies hive',
    );
    await tester.ensureVisible(find.byKey(const Key('save-offering')));
    await tester.tap(find.byKey(const Key('save-offering')));
    await tester.pumpAndSettle();

    expect(find.text('Cookies hive'), findsOneWidget);
    expect(find.text('You already offer this service.'), findsNothing);
  });

  testWidgets('weekday times stay when weekend times are added', (
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

    await tester.tap(find.byKey(const Key('open-days-weekdays')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('open-days-weekdays')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('open-days-weekends')))
          .selected,
      isFalse,
    );
    for (final day in [1, 2, 3, 4, 5]) {
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(ValueKey('open-day-$day')))
            .selected,
        isTrue,
      );
    }
    expect(find.byKey(const ValueKey('open-day-6')), findsNothing);
    expect(find.byKey(const ValueKey('open-day-7')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-day-3')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('open-days-weekdays')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('open-day-3')))
          .selected,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('weekday-hour-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-days-weekends')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('open-days-weekdays')))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('open-days-weekends')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const ValueKey('open-day-1')), findsNothing);
    expect(find.byKey(const ValueKey('weekday-hour-9')), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('open-day-6')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('open-day-7')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('weekend-hour-14')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-day-7')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('open-days-weekends')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('open-day-7')))
          .selected,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('open-days-weekdays')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-day-6')), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('weekday-hour-9')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('open-day-3')))
          .selected,
      isFalse,
    );
    expect(find.byKey(const Key('open-days-every')), findsNothing);
  });
}

Future<void> offerBeautyParlor(WidgetTester tester) async {
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
  await tester.ensureVisible(find.byKey(const ValueKey('weekday-hour-14')));
  await tester.tap(find.byKey(const ValueKey('weekday-hour-14')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('treatment-name-0')),
    'Cut and colour',
  );
  await tester.enterText(
    find.byKey(const ValueKey('treatment-description-0')),
    'A full colour',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('treatment-hours-0-1')));
  await tester.tap(find.byKey(const ValueKey('treatment-hours-0-1')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('treatment-price-0')),
    '200.00',
  );
  await tester.ensureVisible(find.byKey(const Key('save-offering')));
  await tester.tap(find.byKey(const Key('save-offering')));
  await tester.pumpAndSettle();
}

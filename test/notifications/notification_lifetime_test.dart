import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/notifications/domain/app_notification.dart';

import '../support/app_harness.dart';

void main() {
  test('a customer notice stays until the appointment time', () async {
    final harness = AppHarness(now: DateTime(2026, 10, 16, 18, 59));
    final appointment = DateTime(2026, 10, 16, 19);
    await harness.notifications.add(
      AppNotification(
        id: 'notice-1',
        accountId: 'alex',
        appointmentId: 'appt-1',
        kind: BookingNoticeKind.confirmed,
        message:
            'Booking Confirmed: Cookies hive has confirmed your Facial appointment for Fri 16 Oct at 19:00',
        createdAt: DateTime(2026, 10, 14, 10),
        visibleUntil: appointment,
      ),
    );

    expect(await harness.notifications.listFor('alex'), hasLength(1));

    harness.clock.instant = appointment;
    expect(await harness.notifications.listFor('alex'), isEmpty);
    expect(harness.store.notifications, isEmpty);
  });
}

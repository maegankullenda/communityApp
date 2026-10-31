import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/presentation/awaiting_confirmation_page.dart';
import 'package:community_app/presentation/provider_day_page.dart';

void main() {
  ProviderBooking booking(
    DateTime start,
    String name, {
    String serviceId = 'car-wash',
    String serviceName = 'Car wash',
    AppointmentStatus status = AppointmentStatus.booked,
  }) {
    return ProviderBooking(
      appointment: Appointment(
        id: name,
        userId: name,
        slotId: name,
        providerId: 'sam-shine',
        serviceId: serviceId,
        start: start,
        duration: const Duration(hours: 1),
        status: status,
      ),
      serviceName: serviceName,
      customerName: name,
    );
  }

  test('a day lists its bookings from earliest to latest', () {
    final monday = DateTime(2026, 10, 5);
    final bookings = [
      booking(DateTime(2026, 10, 5, 15), 'Late'),
      booking(DateTime(2026, 10, 6, 8), 'Tuesday'),
      booking(DateTime(2026, 10, 5, 9), 'Early'),
      booking(DateTime(2026, 10, 5, 11), 'Mid'),
    ];

    final day = bookingsOnDay(bookings, monday);

    expect(day.map((item) => item.customerName), ['Early', 'Mid', 'Late']);
  });

  test('several services each list their bookings from earliest to latest', () {
    final bookings = [
      booking(DateTime(2026, 10, 5, 15), 'Wash late'),
      booking(
        DateTime(2026, 10, 5, 9),
        'Beauty early',
        serviceId: 'beauty',
        serviceName: 'Beauty',
      ),
      booking(DateTime(2026, 10, 5, 11), 'Wash early'),
      booking(
        DateTime(2026, 10, 5, 16),
        'Beauty late',
        serviceId: 'beauty',
        serviceName: 'Beauty',
      ),
    ];

    final groups = bookingsByService(
      bookingsOnDay(bookings, DateTime(2026, 10, 5)),
      serviceOrder: const ['car-wash', 'beauty'],
    );

    expect(groups.map((group) => group.serviceId), ['car-wash', 'beauty']);
    expect(groups[0].bookings.map((item) => item.customerName), [
      'Wash early',
      'Wash late',
    ]);
    expect(groups[1].bookings.map((item) => item.customerName), [
      'Beauty early',
      'Beauty late',
    ]);
  });

  test('awaiting bookings follow the date the customer requested', () {
    final bookings = [
      booking(
        DateTime(2026, 10, 12, 9),
        'Later',
        serviceId: 'beauty',
        serviceName: 'Beauty',
        status: AppointmentStatus.pending,
      ),
      booking(
        DateTime(2026, 10, 6, 15),
        'Sooner',
        serviceId: 'beauty',
        serviceName: 'Beauty',
        status: AppointmentStatus.pending,
      ),
      booking(DateTime(2026, 10, 5, 9), 'Already confirmed'),
    ];

    final groups = bookingsByService(
      awaitingBookings(bookings),
      serviceOrder: const ['beauty'],
    );

    expect(groups.single.serviceId, 'beauty');
    expect(groups.single.bookings.map((item) => item.customerName), [
      'Sooner',
      'Later',
    ]);
  });

  test('a service is titled with the name the provider gave it', () {
    expect(
      providerServiceName(
        offeringName: 'Cookies hive',
        providerName: "Maegan's Rides",
        catalogName: 'Beauty',
      ),
      'Cookies hive',
    );
    expect(
      providerServiceName(
        offeringName: null,
        providerName: "Sam's Shine",
        catalogName: 'Car wash',
      ),
      "Sam's Shine",
    );
  });
}

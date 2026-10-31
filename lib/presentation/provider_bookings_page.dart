import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/presentation/booking_calendar.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';
import 'package:community_app/presentation/widgets/sign_out_button.dart';

class ProviderBookingsPage extends ConsumerWidget {
  const ProviderBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(providerBookingsProvider);
    final now = ref.watch(clockProvider).now();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: const [SignOutButton()],
      ),
      body: AsyncView(
        value: bookings,
        data: (items) {
          return ListView(
            padding: pagePadding,
            children: [
              Text(
                'Bookings land here as soon as a neighbour reserves a time.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _ProviderBookings(
                bookings: items,
                initialMonth: DateTime(now.year, now.month),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderBookings extends StatelessWidget {
  const _ProviderBookings({required this.bookings, required this.initialMonth});

  final List<ProviderBooking> bookings;
  final DateTime initialMonth;

  @override
  Widget build(BuildContext context) {
    final confirmed = [
      for (final booking in bookings)
        if (booking.appointment.isConfirmed) booking,
    ];
    final awaitingCount = bookings
        .where(
          (booking) => booking.appointment.status == AppointmentStatus.pending,
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('booking-tab-calendar'),
              label: const Text('Calendar'),
              selected: true,
              onSelected: (_) {},
            ),
            ChoiceChip(
              key: const Key('booking-tab-awaiting'),
              label: Text(
                awaitingCount == 0
                    ? 'Awaiting confirmation'
                    : 'Awaiting confirmation ($awaitingCount)',
              ),
              selected: false,
              onSelected: (_) => context.push('/provider/bookings/awaiting'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BookingCalendar(bookings: confirmed, initialMonth: initialMonth),
      ],
    );
  }
}

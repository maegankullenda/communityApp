import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/provider_day_page.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

/// Pending bookings, earliest requested visit first.
List<ProviderBooking> awaitingBookings(List<ProviderBooking> bookings) {
  final pending = [
    for (final booking in bookings)
      if (booking.appointment.status == AppointmentStatus.pending) booking,
  ]..sort((a, b) => a.appointment.start.compareTo(b.appointment.start));
  return pending;
}

class AwaitingConfirmationPage extends ConsumerWidget {
  const AwaitingConfirmationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(providerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Awaiting confirmation')),
      body: AsyncView(
        value: bookings,
        data: (items) {
          final pending = awaitingBookings(items);
          if (pending.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No bookings are waiting for confirmation.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final services =
              ref.watch(providerServicesProvider).asData?.value ?? const [];
          final providerId = ref.watch(sessionProvider)?.providerId;
          final providerName = providerId == null
              ? null
              : ref
                    .watch(providerByIdProvider(providerId))
                    .asData
                    ?.value
                    ?.displayName;
          final offeringNames =
              ref.watch(providerOfferingNamesProvider).asData?.value ??
              const <String, String>{};
          final groups = bookingsByService(
            pending,
            serviceOrder: [for (final service in services) service.id],
          );
          return ListView(
            padding: pagePadding,
            children: [
              for (final group in groups) ...[
                _AwaitingService(
                  serviceId: group.serviceId,
                  title: providerServiceName(
                    offeringName: offeringNames[group.serviceId],
                    providerName: providerName,
                    catalogName: group.bookings.first.serviceName,
                  ),
                  bookings: group.bookings,
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AwaitingService extends StatefulWidget {
  const _AwaitingService({
    required this.serviceId,
    required this.title,
    required this.bookings,
  });

  final String serviceId;
  final String title;
  final List<ProviderBooking> bookings;

  @override
  State<_AwaitingService> createState() => _AwaitingServiceState();
}

class _AwaitingServiceState extends State<_AwaitingService> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            key: ValueKey('awaiting-service-${widget.serviceId}'),
            title: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  for (final booking in widget.bookings) ...[
                    _AwaitingBooking(booking: booking),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AwaitingBooking extends ConsumerWidget {
  const _AwaitingBooking({required this.booking});

  final ProviderBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final appointment = booking.appointment;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: ValueKey('provider-booking-${appointment.id}'),
            onTap: () =>
                context.push('/provider/bookings/booking/${appointment.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.customerName, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(formatAppointmentWhen(appointment.start)),
                  if (appointment.washName != null) ...[
                    const SizedBox(height: 4),
                    Text(appointment.washName!),
                  ],
                  if (appointment.vehicleLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(appointment.vehicleLabel!),
                  ],
                  const SizedBox(height: 8),
                  Text('Tap for contact details.', style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    key: ValueKey('confirm-booking-${appointment.id}'),
                    onPressed: () => _confirm(ref, appointment.id),
                    child: const Text('Confirm booking'),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: ValueKey('decline-booking-${appointment.id}'),
                    onPressed: () => context.push(
                      '/provider/bookings/awaiting/${appointment.id}',
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(WidgetRef ref, String appointmentId) async {
    final providerId = ref.read(sessionProvider)?.providerId;
    if (providerId == null) {
      return;
    }
    await ref
        .read(confirmAppointmentProvider)
        .call(providerId: providerId, appointmentId: appointmentId);
    invalidateBookingViews(ref);
  }
}

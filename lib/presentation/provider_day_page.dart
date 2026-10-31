import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

List<ProviderBooking> bookingsOnDay(
  List<ProviderBooking> bookings,
  DateTime day,
) {
  final matches = [
    for (final booking in bookings)
      if (booking.appointment.start.year == day.year &&
          booking.appointment.start.month == day.month &&
          booking.appointment.start.day == day.day)
        booking,
  ]..sort((a, b) => a.appointment.start.compareTo(b.appointment.start));
  return matches;
}

/// Bookings for one day, split by service and ordered from earliest to latest.
///
/// [serviceOrder] is the provider's service ids. Groups follow that order,
/// then any other service that has a booking.
List<({String serviceId, List<ProviderBooking> bookings})> bookingsByService(
  List<ProviderBooking> dayBookings, {
  List<String> serviceOrder = const [],
}) {
  final grouped = <String, List<ProviderBooking>>{};
  for (final booking in dayBookings) {
    (grouped[booking.appointment.serviceId] ??= []).add(booking);
  }
  for (final bookings in grouped.values) {
    bookings.sort((a, b) => a.appointment.start.compareTo(b.appointment.start));
  }
  final serviceIds = [
    for (final serviceId in serviceOrder)
      if (grouped.containsKey(serviceId)) serviceId,
    for (final serviceId in grouped.keys)
      if (!serviceOrder.contains(serviceId)) serviceId,
  ];
  return [
    for (final serviceId in serviceIds)
      (serviceId: serviceId, bookings: grouped[serviceId]!),
  ];
}

/// The name this provider uses for a service.
///
/// An offering name such as Cookies hive wins. Otherwise the provider's own
/// name is used, and the category name is only a last resort.
String providerServiceName({
  required String? offeringName,
  required String? providerName,
  required String catalogName,
}) {
  final offering = offeringName?.trim() ?? '';
  if (offering.isNotEmpty) {
    return offering;
  }
  final provider = providerName?.trim() ?? '';
  if (provider.isNotEmpty) {
    return provider;
  }
  return catalogName;
}

class ProviderDayPage extends ConsumerWidget {
  const ProviderDayPage({required this.day, super.key});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(providerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(formatDay(day))),
      body: AsyncView(
        value: bookings,
        data: (items) {
          final dayBookings = bookingsOnDay(items, day);
          if (dayBookings.isEmpty) {
            return const Center(child: Text('No bookings on this day.'));
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
            dayBookings,
            serviceOrder: [for (final service in services) service.id],
          );
          return ListView(
            padding: pagePadding,
            children: [
              for (final group in groups) ...[
                _ServiceBookings(
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

class _ServiceBookings extends StatelessWidget {
  const _ServiceBookings({
    required this.serviceId,
    required this.title,
    required this.bookings,
  });

  final String serviceId;
  final String title;
  final List<ProviderBooking> bookings;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('day-service-$serviceId'),
        initiallyExpanded: true,
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final booking in bookings) ...[
            _BookingCard(booking: booking),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final ProviderBooking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final appointment = booking.appointment;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('provider-booking-${appointment.id}'),
        onTap: () =>
            context.push('/provider/bookings/booking/${appointment.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatTime(appointment.start), style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(booking.customerName, style: textTheme.titleMedium),
              Text(
                formatAppointmentWhen(appointment.start),
                style: textTheme.bodySmall,
              ),
              if (appointment.washName != null) ...[
                const SizedBox(height: 4),
                Text(appointment.washName!),
              ],
              if (appointment.vehicleLabel != null) ...[
                const SizedBox(height: 4),
                Text(appointment.vehicleLabel!),
              ],
              if (appointment.priceCents != null) ...[
                const SizedBox(height: 4),
                Text(
                  appointment.washName == null
                      ? formatPrice(appointment.priceCents!)
                      : formatRand(appointment.priceCents!),
                ),
              ],
              const SizedBox(height: 8),
              Text('Tap for contact details.', style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

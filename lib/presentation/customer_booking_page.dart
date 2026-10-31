import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class CustomerBookingPage extends ConsumerWidget {
  const CustomerBookingPage({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(providerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: AsyncView(
        value: bookings,
        data: (items) {
          ProviderBooking? booking;
          for (final item in items) {
            if (item.appointment.id == appointmentId) {
              booking = item;
            }
          }
          if (booking == null) {
            return const Center(
              child: Text('That booking is no longer listed.'),
            );
          }
          final textTheme = Theme.of(context).textTheme;
          return ListView(
            padding: pagePadding,
            children: [
              Text(
                formatAppointmentWhen(booking.appointment.start),
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              _ContactLine(
                label: 'Name',
                value: booking.customerFirstName,
                fieldKey: const Key('customer-first-name'),
              ),
              _ContactLine(
                label: 'Surname',
                value: booking.customerSurname,
                fieldKey: const Key('customer-surname'),
              ),
              _ContactLine(
                label: 'Contact number',
                value: booking.contactNumber,
                fieldKey: const Key('customer-contact-number'),
              ),
              _ContactLine(
                label: 'Address',
                value: booking.address,
                fieldKey: const Key('customer-address'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.label,
    required this.value,
    required this.fieldKey,
  });

  final String label;
  final String value;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shown = value.trim().isEmpty ? 'Not added yet' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(shown, key: fieldKey, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/presentation/activity_page.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class DeclinedBookingPage extends ConsumerWidget {
  const DeclinedBookingPage({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointment = ref.watch(appointmentByIdProvider(appointmentId));
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Declined')),
      body: AsyncView(
        value: appointment,
        data: (booking) {
          if (booking == null || booking.status != AppointmentStatus.declined) {
            return const Center(
              child: Text('That message is no longer listed.'),
            );
          }
          final from = booking.suggestedFrom;
          final until = booking.suggestedUntil;
          return ListView(
            padding: pagePadding,
            children: [
              Text('Message from the provider', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(booking.declineMessage, key: const Key('declined-message')),
              if (from != null && until != null) ...[
                const SizedBox(height: 20),
                Text('Suggested dates', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  formatSuggestedRange(from, until),
                  key: const Key('declined-dates'),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('edit-declined-booking'),
                onPressed: () => context.push(
                  '/services/${booking.serviceId}/providers/${booking.providerId}?appointment=${booking.id}',
                ),
                child: const Text('Edit booking'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('delete-declined-booking'),
                onPressed: () async {
                  final removed = await confirmCancelBooking(
                    context,
                    ref,
                    booking.id,
                    title: 'Delete this booking?',
                    detail: 'It will be removed from your bookings.',
                    confirmLabel: 'Delete booking',
                  );
                  if (removed && context.mounted) {
                    context.pop();
                  }
                },
                child: const Text('Delete booking'),
              ),
            ],
          );
        },
      ),
    );
  }
}

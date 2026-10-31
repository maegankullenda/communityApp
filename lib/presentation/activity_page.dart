import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/result.dart';
import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/format.dart';
import 'package:community_app/presentation/messages.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';
import 'package:community_app/presentation/widgets/sign_out_button.dart';

class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(myActivityProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your bookings'),
        actions: const [SignOutButton()],
      ),
      body: AsyncView(
        value: activity,
        data: (feed) {
          if (feed.appointments.isEmpty && feed.orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing booked yet. When you reserve a time or place a meal order, it will show up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: pagePadding,
            children: [
              Text('Appointments and meal orders.', style: textTheme.bodySmall),
              const SizedBox(height: 16),
              _BookingTabs(appointments: feed.appointments),
              const SizedBox(height: 8),
              Text('Orders', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              if (feed.orders.isEmpty)
                const Text('No meal orders yet.')
              else
                for (final summary in feed.orders) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.serviceName,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(summary.providerName),
                          const SizedBox(height: 8),
                          for (final line in summary.order.lines)
                            Text('${line.quantity} x ${line.name}'),
                          const SizedBox(height: 8),
                          Text(
                            'Total ${formatPrice(summary.order.totalCents)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _BookingTabs extends StatefulWidget {
  const _BookingTabs({required this.appointments});

  final List<AppointmentSummary> appointments;

  @override
  State<_BookingTabs> createState() => _BookingTabsState();
}

class _BookingTabsState extends State<_BookingTabs> {
  AppointmentStatus? _selected;

  AppointmentStatus _current() {
    final selected = _selected;
    if (selected != null) {
      return selected;
    }
    if (widget.appointments.any((item) => item.appointment.isConfirmed)) {
      return AppointmentStatus.booked;
    }
    if (widget.appointments.any(
      (item) => item.appointment.status == AppointmentStatus.pending,
    )) {
      return AppointmentStatus.pending;
    }
    return AppointmentStatus.declined;
  }

  @override
  Widget build(BuildContext context) {
    final current = _current();
    final visible = [
      for (final summary in widget.appointments)
        if (summary.appointment.status == current) summary,
    ];
    final pendingCount = widget.appointments
        .where(
          (summary) => summary.appointment.status == AppointmentStatus.pending,
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('booking-tab-confirmed'),
              label: const Text('Confirmed'),
              selected: current == AppointmentStatus.booked,
              onSelected: (_) =>
                  setState(() => _selected = AppointmentStatus.booked),
            ),
            ChoiceChip(
              key: const Key('booking-tab-pending'),
              label: Text(
                pendingCount == 0
                    ? 'Pending confirmation'
                    : 'Pending confirmation ($pendingCount)',
              ),
              selected: current == AppointmentStatus.pending,
              onSelected: (_) =>
                  setState(() => _selected = AppointmentStatus.pending),
            ),
            ChoiceChip(
              key: const Key('booking-tab-declined'),
              label: const Text('Declined'),
              selected: current == AppointmentStatus.declined,
              onSelected: (_) =>
                  setState(() => _selected = AppointmentStatus.declined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Text(_emptyTab(current))
        else
          for (final summary in visible) ...[
            _AppointmentCard(summary: summary),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

String _emptyTab(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.booked => 'No confirmed bookings.',
    AppointmentStatus.pending => 'No bookings are waiting for confirmation.',
    AppointmentStatus.declined => 'No declined bookings.',
    AppointmentStatus.cancelled => 'No cancelled bookings.',
  };
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({required this.summary});

  final AppointmentSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final appointment = summary.appointment;
    final declined = appointment.status == AppointmentStatus.declined;
    final pending = appointment.status == AppointmentStatus.pending;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('booking-card-${appointment.id}'),
        onTap: declined
            ? () => context.push('/activity/${appointment.id}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.serviceName, style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(summary.providerName),
              const SizedBox(height: 4),
              Text(
                formatAppointmentWhen(appointment.start),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                bookingConfirmationLabel(appointment.status),
                key: ValueKey('booking-status-${appointment.id}'),
                style: textTheme.bodyMedium?.copyWith(
                  color: _bookingStatusColor(context, appointment.status),
                ),
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
              if (declined) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap to read the provider\'s message.',
                  style: textTheme.bodySmall,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: ValueKey('delete-appointment-${appointment.id}'),
                    onPressed: () => confirmCancelBooking(
                      context,
                      ref,
                      appointment.id,
                      title: 'Delete this booking?',
                      detail: 'It will be removed from your bookings.',
                      confirmLabel: 'Delete booking',
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ] else if (pending || appointment.isConfirmed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      key: ValueKey('edit-appointment-${appointment.id}'),
                      onPressed: () {
                        context.go(
                          '/services/${appointment.serviceId}/providers/${appointment.providerId}?appointment=${appointment.id}',
                        );
                      },
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      key: ValueKey('cancel-appointment-${appointment.id}'),
                      onPressed: () =>
                          confirmCancelBooking(context, ref, appointment.id),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _confirmedGreen = Color(0xFF1F6B4A);
const _pendingOrange = Color(0xFFE65100);

Color _bookingStatusColor(BuildContext context, AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.booked => _confirmedGreen,
    AppointmentStatus.pending => _pendingOrange,
    AppointmentStatus.declined => Theme.of(context).colorScheme.error,
    AppointmentStatus.cancelled => Theme.of(context).colorScheme.onSurface,
  };
}

Future<bool> confirmCancelBooking(
  BuildContext context,
  WidgetRef ref,
  String appointmentId, {
  String title = 'Cancel this booking?',
  String detail = 'The time will open up again.',
  String confirmLabel = 'Cancel booking',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            key: const Key('confirm-cancel-booking'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  final userId = ref.read(sessionProvider)?.id;
  if (userId == null) {
    return false;
  }
  final result = await ref
      .read(cancelAppointmentProvider)
      .call(userId: userId, appointmentId: appointmentId);
  if (!context.mounted) {
    return false;
  }
  invalidateBookingViews(ref);
  if (result case Err(:final error)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(bookingFailureMessage(error))));
    return false;
  }
  return true;
}

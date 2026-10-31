import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/presentation/appointment_page.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/menu_page.dart';
import 'package:community_app/presentation/widgets/async_view.dart';

class OfferingPage extends ConsumerWidget {
  const OfferingPage({
    required this.serviceId,
    required this.providerId,
    this.appointmentId,
    super.key,
  });

  final String serviceId;
  final String providerId;
  final String? appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceByIdProvider(serviceId));
    final provider = ref.watch(providerByIdProvider(providerId));

    return AsyncView(
      value: service,
      data: (foundService) {
        return AsyncView(
          value: provider,
          data: (foundProvider) {
            if (foundService == null || foundProvider == null) {
              return const Scaffold(
                body: Center(child: Text('That offering is not listed.')),
              );
            }
            if (appointmentId == null &&
                !foundProvider.isActive(foundService.id)) {
              return const Scaffold(
                body: Center(
                  child: Text('This provider is not taking bookings right now.'),
                ),
              );
            }
            return switch (foundService.fulfillment) {
              FulfillmentKind.appointment => AppointmentPage(
                service: foundService,
                provider: foundProvider,
                appointmentId: appointmentId,
              ),
              FulfillmentKind.order => MenuPage(
                service: foundService,
                provider: foundProvider,
              ),
            };
          },
        );
      },
    );
  }
}

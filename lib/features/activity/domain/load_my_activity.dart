import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

final class LoadMyActivity {
  const LoadMyActivity({
    required SchedulingRepository scheduling,
    required OrderingRepository ordering,
    required CatalogRepository catalog,
    required OfferingRepository offerings,
  }) : _scheduling = scheduling,
       _ordering = ordering,
       _catalog = catalog,
       _offerings = offerings;

  final SchedulingRepository _scheduling;
  final OrderingRepository _ordering;
  final CatalogRepository _catalog;
  final OfferingRepository _offerings;

  Future<MyActivity> call(String userId) async {
    final appointments = await _scheduling.appointmentsForUser(userId);
    final orders = await _ordering.ordersForUser(userId);

    final appointmentSummaries = <AppointmentSummary>[];
    for (final appointment in appointments.where(
      (item) => item.isListedForCustomer,
    )) {
      final service = await _catalog.findService(appointment.serviceId);
      final provider = await _catalog.findProvider(appointment.providerId);
      final offering = await _offerings.find(
        providerId: appointment.providerId,
        serviceId: appointment.serviceId,
      );
      appointmentSummaries.add(
        AppointmentSummary(
          appointment: appointment,
          serviceName: service?.name ?? appointment.serviceId,
          providerName:
              offering?.name ?? provider?.displayName ?? appointment.providerId,
        ),
      );
    }
    appointmentSummaries.sort(
      (a, b) => a.appointment.start.compareTo(b.appointment.start),
    );

    final orderSummaries = <OrderSummary>[];
    for (final order in orders.where((item) => item.isActive)) {
      final service = await _catalog.findService(order.serviceId);
      final provider = await _catalog.findProvider(order.providerId);
      final offering = await _offerings.find(
        providerId: order.providerId,
        serviceId: order.serviceId,
      );
      orderSummaries.add(
        OrderSummary(
          order: order,
          serviceName: service?.name ?? order.serviceId,
          providerName:
              offering?.name ?? provider?.displayName ?? order.providerId,
        ),
      );
    }
    orderSummaries.sort((a, b) => b.order.placedAt.compareTo(a.order.placedAt));

    return MyActivity(
      appointments: appointmentSummaries,
      orders: orderSummaries,
    );
  }
}

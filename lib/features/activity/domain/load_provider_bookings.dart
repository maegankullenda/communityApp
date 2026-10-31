import 'package:community_app/features/activity/domain/activity_summary.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

final class LoadProviderBookings {
  const LoadProviderBookings({
    required SchedulingRepository scheduling,
    required CatalogRepository catalog,
    required AuthRepository auth,
    required ProfileRepository profiles,
  }) : _scheduling = scheduling,
       _catalog = catalog,
       _auth = auth,
       _profiles = profiles;

  final SchedulingRepository _scheduling;
  final CatalogRepository _catalog;
  final AuthRepository _auth;
  final ProfileRepository _profiles;

  Future<List<ProviderBooking>> call(String providerId) async {
    final appointments = await _scheduling.appointmentsForProvider(providerId);
    final active = appointments.where((item) => item.isActive).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final bookings = <ProviderBooking>[];
    for (final appointment in active) {
      final service = await _catalog.findService(appointment.serviceId);
      final customer = await _auth.findById(appointment.userId);
      final profile = await _profiles.find(appointment.userId);
      bookings.add(
        ProviderBooking(
          appointment: appointment,
          serviceName: service?.name ?? appointment.serviceId,
          customerName: customer?.displayName ?? appointment.userId,
          customerFirstName: profile.firstName,
          customerSurname: profile.surname,
          contactNumber: profile.contactNumber,
          address: profile.address,
        ),
      );
    }
    return bookings;
  }
}

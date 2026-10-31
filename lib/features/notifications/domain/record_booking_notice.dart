import 'package:community_app/core/clock.dart';
import 'package:community_app/core/id_generator.dart';
import 'package:community_app/features/catalog/domain/catalog_repository.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';
import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/features/notifications/domain/notification_repository.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';

final class RecordBookingNotice {
  const RecordBookingNotice({
    required NotificationRepository notifications,
    required ProfileRepository profiles,
    required CatalogRepository catalog,
    required OfferingRepository offerings,
    required AuthRepository auth,
    required IdGenerator ids,
    required Clock clock,
  }) : _notifications = notifications,
       _profiles = profiles,
       _catalog = catalog,
       _offerings = offerings,
       _auth = auth,
       _ids = ids,
       _clock = clock;

  final NotificationRepository _notifications;
  final ProfileRepository _profiles;
  final CatalogRepository _catalog;
  final OfferingRepository _offerings;
  final AuthRepository _auth;
  final IdGenerator _ids;
  final Clock _clock;

  Future<void> requested(Appointment appointment) async {
    final provider = await _auth.findByProviderId(appointment.providerId);
    if (provider == null) {
      return;
    }
    await _notifications.add(
      AppNotification(
        id: _ids.next('notice'),
        accountId: provider.id,
        appointmentId: appointment.id,
        kind: BookingNoticeKind.requested,
        message: bookingRequestedMessage(
          customerName: await _customerName(appointment.userId),
          serviceName: await _serviceName(appointment),
        ),
        createdAt: _clock.now(),
      ),
    );
  }

  Future<void> confirmed(Appointment appointment) async {
    final when = noticeWhen(appointment.start);
    await _notifications.removeRequested(appointment.id);
    await _reply(
      appointment,
      kind: BookingNoticeKind.confirmed,
      visibleUntil: appointment.start,
      message: ({required String providerName, required String serviceName}) {
        return bookingConfirmedMessage(
          providerName: providerName,
          serviceName: serviceName,
          when: when,
        );
      },
    );
  }

  Future<void> declined(Appointment appointment) async {
    await _notifications.removeRequested(appointment.id);
    await _reply(
      appointment,
      kind: BookingNoticeKind.declined,
      visibleUntil: appointment.start,
      message: bookingDeclinedMessage,
    );
  }

  Future<void> _reply(
    Appointment appointment, {
    required BookingNoticeKind kind,
    required String Function({
      required String providerName,
      required String serviceName,
    })
    message,
    DateTime? visibleUntil,
  }) async {
    await _notifications.add(
      AppNotification(
        id: _ids.next('notice'),
        accountId: appointment.userId,
        appointmentId: appointment.id,
        kind: kind,
        message: message(
          providerName: await _providerName(appointment),
          serviceName: await _serviceName(appointment),
        ),
        createdAt: _clock.now(),
        visibleUntil: visibleUntil,
      ),
    );
  }

  Future<String> _customerName(String userId) async {
    final profile = await _profiles.find(userId);
    final firstName = profile.firstName.trim();
    if (firstName.isNotEmpty) {
      return firstName;
    }
    final account = await _auth.findById(userId);
    final displayName = account?.displayName.trim() ?? '';
    return displayName.isEmpty ? 'A customer' : displayName;
  }

  Future<String> _serviceName(Appointment appointment) async {
    final booked = appointment.washName?.trim() ?? '';
    if (booked.isNotEmpty) {
      return booked;
    }
    final offering = await _offerings.find(
      providerId: appointment.providerId,
      serviceId: appointment.serviceId,
    );
    final offeringName = offering?.name.trim() ?? '';
    if (offeringName.isNotEmpty) {
      return offeringName;
    }
    final service = await _catalog.findService(appointment.serviceId);
    final category = service?.name.trim() ?? '';
    return category.isEmpty ? 'service' : category;
  }

  Future<String> _providerName(Appointment appointment) async {
    final offering = await _offerings.find(
      providerId: appointment.providerId,
      serviceId: appointment.serviceId,
    );
    final offeringName = offering?.name.trim() ?? '';
    if (offeringName.isNotEmpty) {
      return offeringName;
    }
    final provider = await _catalog.findProvider(appointment.providerId);
    final displayName = provider?.displayName.trim() ?? '';
    return displayName.isEmpty ? 'Your provider' : displayName;
  }
}

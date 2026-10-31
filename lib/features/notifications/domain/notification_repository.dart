import 'package:community_app/features/notifications/domain/app_notification.dart';

abstract interface class NotificationRepository {
  Future<List<AppNotification>> listFor(String accountId);

  Future<void> add(AppNotification notification);

  Future<void> markAllRead(String accountId);

  /// Drops the provider's request notice after they confirm or decline.
  Future<void> removeRequested(String appointmentId);
}

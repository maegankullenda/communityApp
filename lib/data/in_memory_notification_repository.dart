import 'package:community_app/core/clock.dart';
import 'package:community_app/data/community_store.dart';
import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/features/notifications/domain/notification_repository.dart';

final class InMemoryNotificationRepository implements NotificationRepository {
  InMemoryNotificationRepository(this._store, {required Clock clock})
    : _clock = clock;

  final CommunityStore _store;
  final Clock _clock;

  void _dropExpired() {
    final now = _clock.now();
    for (final notice in _store.notifications.values.toList()) {
      final until = notice.visibleUntil;
      if (until != null && !now.isBefore(until)) {
        _store.notifications.remove(notice.id);
      }
    }
  }

  @override
  Future<List<AppNotification>> listFor(String accountId) async {
    _dropExpired();
    final notices =
        [
          for (final notice in _store.notifications.values)
            if (notice.accountId == accountId) notice,
        ]..sort((a, b) {
          final byTime = b.createdAt.compareTo(a.createdAt);
          return byTime == 0 ? b.id.compareTo(a.id) : byTime;
        });
    return notices;
  }

  @override
  Future<void> add(AppNotification notification) async {
    _store.notifications[notification.id] = notification;
  }

  @override
  Future<void> removeRequested(String appointmentId) async {
    _store.notifications.removeWhere(
      (_, notice) =>
          notice.appointmentId == appointmentId &&
          notice.kind == BookingNoticeKind.requested,
    );
  }

  @override
  Future<void> markAllRead(String accountId) async {
    for (final notice in _store.notifications.values.toList()) {
      if (notice.accountId == accountId && !notice.read) {
        _store.notifications[notice.id] = notice.copyWith(read: true);
      }
    }
  }
}

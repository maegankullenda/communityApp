import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/theme.dart';
import 'package:community_app/presentation/widgets/async_view.dart';
import 'package:community_app/presentation/widgets/sign_out_button.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _marking = false;

  Future<void> _markRead() async {
    if (_marking) {
      return;
    }
    final accountId = ref.read(sessionProvider)?.id;
    if (accountId == null) {
      return;
    }
    _marking = true;
    await ref.read(notificationRepositoryProvider).markAllRead(accountId);
    if (!mounted) {
      return;
    }
    ref.invalidate(notificationsProvider);
    _marking = false;
  }

  void _open(AppNotification notice) {
    switch (notice.kind) {
      case BookingNoticeKind.requested:
        context.go('/provider/bookings/awaiting');
      case BookingNoticeKind.confirmed:
        context.go('/activity');
      case BookingNoticeKind.declined:
        context.go('/activity/${notice.appointmentId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notices = ref.watch(notificationsProvider);
    final showing = TickerMode.of(context);
    final unread = notices.asData?.value.any((notice) => !notice.read) ?? false;
    if (showing && unread) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _markRead();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: const [SignOutButton()],
      ),
      body: AsyncView(
        value: notices,
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No notifications yet.',
                  key: Key('notifications-empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: pagePadding,
            children: [
              for (final notice in items) ...[
                Card(
                  child: ListTile(
                    key: ValueKey(
                      'notification-${notice.appointmentId}-${notice.kind.name}',
                    ),
                    title: Text(notice.message),
                    onTap: () => _open(notice),
                  ),
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

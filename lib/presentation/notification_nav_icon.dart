import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/presentation/dependencies.dart';

class NotificationNavIcon extends ConsumerStatefulWidget {
  const NotificationNavIcon({super.key});

  @override
  ConsumerState<NotificationNavIcon> createState() =>
      _NotificationNavIconState();
}

class _NotificationNavIconState extends ConsumerState<NotificationNavIcon> {
  var _count = 0;

  int _unread(AsyncValue<List<AppNotification>> notices) {
    return notices.asData?.value.where((notice) => !notice.read).length ?? 0;
  }

  void _apply(int count) {
    if (!mounted || count == _count) {
      return;
    }
    setState(() => _count = count);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (
      _,
      next,
    ) {
      _apply(_unread(next));
    });
    final icon = const Icon(Icons.notifications_outlined);
    if (_count == 0) {
      return icon;
    }
    return Badge.count(
      key: const Key('notification-count'),
      count: _count,
      child: icon,
    );
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _apply(_unread(ref.read(notificationsProvider)));
    });
  }
}

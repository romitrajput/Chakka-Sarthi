import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/badge_widget.dart';
import 'package:sanjay_roadlines_fleet/providers/notification_provider.dart';

class NotificationBell extends ConsumerWidget {
  final VoidCallback onTap;

  const NotificationBell({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: onTap,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: BadgeWidget(
              count: unreadCount,
              size: 16,
              fontSize: 10,
              color: Colors.red,
              textColor: Colors.white,
            ),
          ),
      ],
    );
  }
}

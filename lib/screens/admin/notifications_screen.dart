import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationControllerProvider.notifier).markAllRead(),
            child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (allNotifications) {
          final notifications = allNotifications.where((n) => !n.isRead).toList();
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text('No unread notifications', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: notification.isRead ? AppColors.divider : AppColors.primaryMid.withValues(alpha: 0.3),
                    width: notification.isRead ? 1 : 2,
                  ),
                ),
                color: notification.isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notification.isRead ? AppColors.background : AppColors.primaryMid,
                    child: Icon(
                      notification.isRead ? Icons.notifications_none : Icons.notifications_active,
                      color: notification.isRead ? AppColors.textSecondary : Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notification.message, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        notification.formattedCreatedAt,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

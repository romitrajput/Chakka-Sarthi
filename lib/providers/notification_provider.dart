import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sanjay_roadlines_fleet/models/notification_model.dart';
import 'package:sanjay_roadlines_fleet/repositories/notification_repository.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

part 'notification_provider.g.dart';

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  return NotificationRepository();
}

@riverpod
Stream<List<NotificationModel>> notificationStream(NotificationStreamRef ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return ref.watch(notificationRepositoryProvider).getNotificationsStream(user.userId);
}

@riverpod
int unreadNotificationsCount(UnreadNotificationsCountRef ref) {
  final notifications = ref.watch(notificationStreamProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
}

@riverpod
class NotificationController extends _$NotificationController {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> markAllRead() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead(user.userId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> send({
    required String targetUserId,
    required String title,
    required String message,
    String? ticketId,
  }) async {
    try {
      await ref.read(notificationRepositoryProvider).sendNotification(
            targetUserId: targetUserId,
            title: title,
            message: message,
            ticketId: ticketId,
          );
    } catch (e) {
      // Background operation
    }
  }
}

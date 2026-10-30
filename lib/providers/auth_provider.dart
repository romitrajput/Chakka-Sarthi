import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sanjay_roadlines_fleet/core/utils/local_notification_service.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/core/utils/push_service.dart';
import 'package:sanjay_roadlines_fleet/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository();
}

@riverpod
class AuthState extends _$AuthState {
  @override
  FutureOr<UserModel?> build() async {
    // Restore session only if remember me was checked
    final savedUserId = await ref.read(authRepositoryProvider).getSavedUserId();
    if (savedUserId != null) {
      try {
        final user = await ref.read(authRepositoryProvider).getUserDetails(savedUserId);
        if (user != null) {
          // Start listening for notifications
          LocalNotificationService.startListening(user.userId);
          PushService.registerForCurrentUser();
        }
        return user;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> loginWithPassword(String userId, String password,
      {bool remember = false}) async {
    state = const AsyncValue.loading();
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .loginWithPassword(userId, password, remember: remember);
      state = AsyncValue.data(user);

      // Start listening for notifications
      if (user != null) {
        LocalNotificationService.startListening(user.userId);
        PushService.registerForCurrentUser();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loginWithMpin(String userId, String mpin,
      {bool remember = false}) async {
    state = const AsyncValue.loading();
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .loginWithMpin(userId, mpin, remember: remember);
      state = AsyncValue.data(user);

      // Start listening for notifications
      if (user != null) {
        LocalNotificationService.startListening(user.userId);
        PushService.registerForCurrentUser();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    // Stop notification listener
    LocalNotificationService.stopListening();

    await ref.read(authRepositoryProvider).clearSession();
    state = const AsyncValue.data(null);
  }
}

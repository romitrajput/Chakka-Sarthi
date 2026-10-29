// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationRepositoryHash() => r'8da58d2634b1fc13801bc62ef8296b1496408cae';

/// See also [notificationRepository].
@ProviderFor(notificationRepository)
final notificationRepositoryProvider = AutoDisposeProvider<NotificationRepository>.internal(
  notificationRepository,
  name: r'notificationRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$notificationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationRepositoryRef = AutoDisposeProviderRef<NotificationRepository>;

String _$notificationStreamHash() => r'f7b024c3044d4031433650cee421aab2e183656f';

/// See also [notificationStream].
@ProviderFor(notificationStream)
final notificationStreamProvider = AutoDisposeStreamProvider<List<NotificationModel>>.internal(
  notificationStream,
  name: r'notificationStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$notificationStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationStreamRef = AutoDisposeStreamProviderRef<List<NotificationModel>>;

String _$unreadNotificationsCountHash() => r'a232e2c8d452b058a9110b1759d68b73f125eaed';

/// See also [unreadNotificationsCount].
@ProviderFor(unreadNotificationsCount)
final unreadNotificationsCountProvider = AutoDisposeProvider<int>.internal(
  unreadNotificationsCount,
  name: r'unreadNotificationsCountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$unreadNotificationsCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadNotificationsCountRef = AutoDisposeProviderRef<int>;

String _$notificationControllerHash() => r'b68d568fb80ab22cedee115b91f96f0dbc568254';

/// See also [NotificationController].
@ProviderFor(NotificationController)
final notificationControllerProvider =
    AutoDisposeNotifierProvider<NotificationController, AsyncValue<void>>.internal(
  NotificationController.new,
  name: r'notificationControllerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$notificationControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationController = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

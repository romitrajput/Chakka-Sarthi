// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$vehicleRepositoryHash() => r'dcd93c559b3400fd707e04cda29a329802eae769';

/// See also [vehicleRepository].
@ProviderFor(vehicleRepository)
final vehicleRepositoryProvider = AutoDisposeProvider<VehicleRepository>.internal(
  vehicleRepository,
  name: r'vehicleRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$vehicleRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VehicleRepositoryRef = AutoDisposeProviderRef<VehicleRepository>;

String _$vehicleStateHash() => r'd421b1087f908080ef97d20e976f429526b8bb1f';

/// See also [VehicleState].
@ProviderFor(VehicleState)
final vehicleStateProvider =
    AutoDisposeAsyncNotifierProvider<VehicleState, List<VehicleModel>>.internal(
  VehicleState.new,
  name: r'vehicleStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$vehicleStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VehicleState = AutoDisposeAsyncNotifier<List<VehicleModel>>;

String _$availableVehiclesHash() => r'd0dc386cb613955af755f07bc9112acffe3db354';

/// See also [availableVehicles].
@ProviderFor(availableVehicles)
final availableVehiclesProvider = AutoDisposeFutureProvider<List<VehicleModel>>.internal(
  availableVehicles,
  name: r'availableVehiclesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$availableVehiclesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableVehiclesRef = AutoDisposeFutureProviderRef<List<VehicleModel>>;

String _$allVehicleNumbersHash() => r'a466238ae0dae8002ef8316bf84ca613e2d0678b';

/// See also [allVehicleNumbers].
@ProviderFor(allVehicleNumbers)
final allVehicleNumbersProvider = AutoDisposeFutureProvider<List<String>>.internal(
  allVehicleNumbers,
  name: r'allVehicleNumbersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allVehicleNumbersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AllVehicleNumbersRef = AutoDisposeFutureProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

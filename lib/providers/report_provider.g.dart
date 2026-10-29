// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reportRepositoryHash() => r'4514b658fdca9e337c784fbea728b9fd93837b7f';

/// See also [reportRepository].
@ProviderFor(reportRepository)
final reportRepositoryProvider = AutoDisposeProvider<ReportRepository>.internal(
  reportRepository,
  name: r'reportRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$reportRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReportRepositoryRef = AutoDisposeProviderRef<ReportRepository>;

String _$reportStateHash() => r'8fad2cdc0ac99f337db73adbbf1907518796b6ac';

/// See also [ReportState].
@ProviderFor(ReportState)
final reportStateProvider =
    AutoDisposeAsyncNotifierProvider<ReportState, Map<String, dynamic>>.internal(
  ReportState.new,
  name: r'reportStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$reportStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ReportState = AutoDisposeAsyncNotifier<Map<String, dynamic>>;

String _$vehicleWiseReportHash() => r'609b567f34efab9c2449dfd85f27e6b1fafd8988';

/// See also [vehicleWiseReport].
@ProviderFor(vehicleWiseReport)
final vehicleWiseReportProvider = AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
  vehicleWiseReport,
  name: r'vehicleWiseReportProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$vehicleWiseReportHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VehicleWiseReportRef = AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

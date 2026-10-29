// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ticketRepositoryHash() => r'382f2cefdc51742b220863a10fc5c53e95a52e1a';

/// See also [ticketRepository].
@ProviderFor(ticketRepository)
final ticketRepositoryProvider = AutoDisposeProvider<TicketRepository>.internal(
  ticketRepository,
  name: r'ticketRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$ticketRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TicketRepositoryRef = AutoDisposeProviderRef<TicketRepository>;

String _$ticketStateHash() => r'b4aa69fd336d09de754889966a7710ed50c7ef0f';

/// See also [TicketState].
@ProviderFor(TicketState)
final ticketStateProvider =
    AutoDisposeAsyncNotifierProvider<TicketState, List<TicketModel>>.internal(
  TicketState.new,
  name: r'ticketStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$ticketStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TicketState = AutoDisposeAsyncNotifier<List<TicketModel>>;

String _$completedTicketsHash() => r'eda5fa0d9398b0b1f1c359ed70922daecdb01131';

/// See also [completedTickets].
@ProviderFor(completedTickets)
final completedTicketsProvider = AutoDisposeFutureProvider<List<TicketModel>>.internal(
  completedTickets,
  name: r'completedTicketsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$completedTicketsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CompletedTicketsRef = AutoDisposeFutureProviderRef<List<TicketModel>>;

String _$assignedTicketsHash() => r'f17adb60430da088447252cb81b6b2b680cb8f7e';

/// See also [assignedTickets].
@ProviderFor(assignedTickets)
final assignedTicketsProvider = AutoDisposeFutureProvider<List<TicketModel>>.internal(
  assignedTickets,
  name: r'assignedTicketsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$assignedTicketsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AssignedTicketsRef = AutoDisposeFutureProviderRef<List<TicketModel>>;

String _$allActiveTicketsHash() => r'a961fcdcbc0a60b03723654586fcbfbad9e586c3';

/// See also [allActiveTickets].
@ProviderFor(allActiveTickets)
final allActiveTicketsProvider = AutoDisposeFutureProvider<List<TicketModel>>.internal(
  allActiveTickets,
  name: r'allActiveTicketsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allActiveTicketsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AllActiveTicketsRef = AutoDisposeFutureProviderRef<List<TicketModel>>;

String _$driverTicketsHash() => r'7c28873b9e2ccfae1daacd1177f4cf1ed78d646e';

/// See also [driverTickets].
@ProviderFor(driverTickets)
final driverTicketsProvider = AutoDisposeFutureProvider<List<TicketModel>>.internal(
  driverTickets,
  name: r'driverTicketsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$driverTicketsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DriverTicketsRef = AutoDisposeFutureProviderRef<List<TicketModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

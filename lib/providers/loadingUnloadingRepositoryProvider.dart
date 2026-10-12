import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/models/loading_status_model.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';

// Locally defined providers for screen data fetching
final loadingUnloadingRepositoryProvider = Provider((ref) => LoadingUnloadingRepository());

final ticketDetailProvider = FutureProvider.family<TicketModel, String>((ref, ticketId) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return await repo.getTicketById(ticketId);
});

final loadingStatusDetailProvider = FutureProvider.family<LoadingStatusModel?, String>((ref, ticketId) async {
  final repo = ref.watch(loadingUnloadingRepositoryProvider);
  return await repo.getLoadingStatus(ticketId);
});

final vehicleNumberDetailProvider = FutureProvider.family<String, String>((ref, vehicleId) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return await repo.getVehicleNumber(vehicleId);
});



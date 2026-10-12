import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/repositories/ticket_repository.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

part 'ticket_provider.g.dart';

@riverpod
TicketRepository ticketRepository(TicketRepositoryRef ref) {
  return TicketRepository();
}

@riverpod
class TicketState extends _$TicketState {
  @override
  FutureOr<List<TicketModel>> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return [];
    
    if (user.role == 'admin') {
      return ref.read(ticketRepositoryProvider).getInTransitTickets(user.companyCode);
    } else {
      return ref.read(ticketRepositoryProvider).getDriverTickets(user.userId);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) return [];
      
      if (user.role == 'admin') {
        return ref.read(ticketRepositoryProvider).getInTransitTickets(user.companyCode);
      } else {
        return ref.read(ticketRepositoryProvider).getDriverTickets(user.userId);
      }
    });
  }

  /// Get current driver's tickets for real-time validation
  Future<List<TicketModel>> getDriverTicketsForValidation(String driverUserId) async {
    return ref.read(ticketRepositoryProvider).getDriverTickets(driverUserId);
  }

  Future<void> createTicket({
    required String ticketId,
    required String vehicleId,
    required String driverUserId,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      await ref.read(ticketRepositoryProvider).createTicket(
            ticketId: ticketId,
            vehicleId: vehicleId,
            driverUserId: driverUserId,
            companyCode: user.companyCode,
            createdBy: user.fullName,
            createdByUserId: user.userId,
          );
      await refresh();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> cancelTicket(String ticketId, String vehicleId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(ticketRepositoryProvider).cancelTicket(ticketId, vehicleId);
      await refresh();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // REASSIGN TRIP
  Future<void> reassignTicket({
    required String ticketId,
    required String newDriverUserId,
    String? reason,
    String? reassignedAtStage,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      await ref.read(ticketRepositoryProvider).reassignTicket(
            ticketId: ticketId,
            newDriverUserId: newDriverUserId,
            reassignedBy: user.userId,
            reason: reason,
            reassignedAtStage: reassignedAtStage,
          );
      
      // Immediately refresh to update UI for all users
      await refresh();
      
      // Also refresh the driver tickets provider for the affected drivers
      ref.invalidate(allActiveTicketsProvider);
      ref.invalidate(driverTicketsProvider);
      
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // UPDATE REPORTING DATE
  Future<void> updateReportingDate({
    required String ticketId,
    required DateTime reportingDate,
  }) async {
    try {
      await ref.read(ticketRepositoryProvider).updateReportingDate(
            ticketId: ticketId,
            reportingDate: reportingDate,
          );
    } catch (e) {
      rethrow;
    }
  }

  // UPDATE CHALLAN URLS
  Future<void> updateChallanUrls({
    required String ticketId,
    required List<String> challanUrls,
  }) async {
    try {
      await ref.read(ticketRepositoryProvider).updateChallanUrls(
            ticketId: ticketId,
            challanUrls: challanUrls,
          );
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
Future<List<TicketModel>> completedTickets(CompletedTicketsRef ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(ticketRepositoryProvider).getCompletedTickets(user.companyCode);
}

@riverpod
Future<List<TicketModel>> assignedTickets(AssignedTicketsRef ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(ticketRepositoryProvider).getAssignedTickets(user.companyCode);
}

@riverpod
Future<List<TicketModel>> allActiveTickets(AllActiveTicketsRef ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(ticketRepositoryProvider).getAllActiveTickets(user.companyCode);
}

@riverpod
Future<List<TicketModel>> driverTickets(DriverTicketsRef ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final tickets = await ref.watch(ticketRepositoryProvider).getDriverTickets(user.userId);
  
  // Filter out tickets that are no longer assigned to this driver (after reassignment)
  return tickets.where((t) => t.driverUserId == user.userId).toList();
}

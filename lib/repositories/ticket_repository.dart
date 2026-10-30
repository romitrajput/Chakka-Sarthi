import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/core/utils/detention.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';

class TicketRepository {
  final SupabaseClient _client = Supabase.instance.client;

  static const _cols =
      'id, ticket_id, vehicle_id, driver_user_id, company_code, status, assigned_at, completed_at, created_by, created_by_user_id, pdf_url, created_at, reporting_date, challan_urls, reassigned_from, reassignment_count, retention_days';

  Future<void> createTicket({
    required String ticketId,
    required String vehicleId,
    required String driverUserId,
    required String companyCode,
    required String createdBy,
    String? createdByUserId,
  }) async {
    try {
      final active = await _client
          .from(SupabaseConstants.tableTickets)
          .select('id')
          .eq('driver_user_id', driverUserId)
          .inFilter('status', ['assigned', 'in_transit']);

      if ((active as List).isNotEmpty) {
        throw Exception('Driver already has an active trip');
      }

      final vehicle = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('status')
          .eq('id', vehicleId)
          .maybeSingle();

      if (vehicle == null || vehicle['status'] != 'available') {
        throw Exception('Vehicle is not available');
      }

      await _client.from(SupabaseConstants.tableTickets).insert({
        'ticket_id': ticketId,
        'vehicle_id': vehicleId,
        'driver_user_id': driverUserId,
        'company_code': companyCode,
        'status': 'assigned',
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': createdBy,
        if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      });

      await _client
          .from(SupabaseConstants.tableVehicles)
          .update({'status': 'in_transit'})
          .eq('id', vehicleId);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TicketModel>> getInTransitTickets(String companyCode) async {
    final response = await _client
        .from(SupabaseConstants.tableTickets)
        .select(_cols)
        .eq('company_code', companyCode)
        .eq('status', 'in_transit')
        .order('assigned_at', ascending: false);
    return (response as List)
        .map((j) => TicketModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketModel>> getCompletedTickets(String companyCode) async {
    final response = await _client
        .from(SupabaseConstants.tableTickets)
        .select(_cols)
        .eq('company_code', companyCode)
        .eq('status', 'completed')
        .order('completed_at', ascending: false);
    return (response as List)
        .map((j) => TicketModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketModel>> getAssignedTickets(String companyCode) async {
    final response = await _client
        .from(SupabaseConstants.tableTickets)
        .select(_cols)
        .eq('company_code', companyCode)
        .eq('status', 'assigned')
        .order('assigned_at', ascending: false);
    return (response as List)
        .map((j) => TicketModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketModel>> getAllActiveTickets(String companyCode) async {
    final response = await _client
        .from(SupabaseConstants.tableTickets)
        .select(_cols)
        .eq('company_code', companyCode)
        .inFilter('status', ['assigned', 'in_transit'])
        .order('assigned_at', ascending: false);
    return (response as List)
        .map((j) => TicketModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketModel>> getDriverTickets(String driverUserId) async {
    final response = await _client
        .from(SupabaseConstants.tableTickets)
        .select(_cols)
        .eq('driver_user_id', driverUserId)
        .inFilter('status', ['assigned', 'in_transit'])
        .order('assigned_at', ascending: false);
    return (response as List)
        .map((j) => TicketModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<TicketModel> getTicketById(String ticketId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableTickets)
          .select(_cols)
          .eq('ticket_id', ticketId)
          .limit(1)
          .maybeSingle();

      if (response == null) throw Exception('Ticket not found: $ticketId');
      return TicketModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getVehicleNumber(String vehicleId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('vehicle_number')
          .eq('id', vehicleId)
          .maybeSingle();
      return response?['vehicle_number'] as String? ?? vehicleId;
    } catch (e) {
      return vehicleId;
    }
  }

  Future<void> cancelTicket(String ticketId, String vehicleId) async {
    try {
      final ticket = await _client
          .from(SupabaseConstants.tableTickets)
          .select('status')
          .eq('ticket_id', ticketId)
          .maybeSingle();

      if (ticket == null || ticket['status'] != 'assigned') {
        throw Exception('Only assigned tickets can be cancelled');
      }

      await _client
          .from(SupabaseConstants.tableTickets)
          .update({'status': 'cancelled'})
          .eq('ticket_id', ticketId);

      await _client
          .from(SupabaseConstants.tableVehicles)
          .update({'status': 'available'})
          .eq('id', vehicleId);
    } catch (e) {
      rethrow;
    }
  }

  // REASSIGN TRIP
  Future<void> reassignTicket({
    required String ticketId,
    required String newDriverUserId,
    required String reassignedBy,
    String? reason,
    String? reassignedAtStage,
  }) async {
    try {
      final ticket = await getTicketById(ticketId);
      
      // Determine current stage if not provided
      final stage = reassignedAtStage ?? ticket.currentStage;

      // Check if new driver has an active trip
      final active = await _client
          .from(SupabaseConstants.tableTickets)
          .select('id')
          .eq('driver_user_id', newDriverUserId)
          .inFilter('status', ['assigned', 'in_transit']);

      if ((active as List).isNotEmpty) {
        throw Exception('New driver already has an active trip');
      }

      // Update ticket with new driver
      await _client
          .from(SupabaseConstants.tableTickets)
          .update({
            'driver_user_id': newDriverUserId,
            'reassigned_from': ticket.driverUserId,
            'reassignment_count': ticket.reassignmentCount + 1,
          })
          .eq('ticket_id', ticketId);

      // Log reassignment with stage
      await _client
          .from(SupabaseConstants.tableTripReassignments)
          .insert({
            'ticket_id': ticketId,
            'old_driver_user_id': ticket.driverUserId,
            'new_driver_user_id': newDriverUserId,
            'reassigned_by': reassignedBy,
            'reason': reason,
            'reassigned_at_stage': stage,
          });
    } catch (e) {
      rethrow;
    }
  }

  // UPDATE REPORTING DATE (+ detention days = unloading date − reporting date)
  Future<void> updateReportingDate({
    required String ticketId,
    required DateTime reportingDate,
    DateTime? unloadingDate,
  }) async {
    try {
      // Use the unloading date passed in; otherwise look it up
      DateTime? unloading = unloadingDate;
      if (unloading == null) {
        final unloadingRes = await _client
            .from(SupabaseConstants.tableUnloadingStatus)
            .select('unloading_date')
            .eq('ticket_id', ticketId)
            .maybeSingle();
        final raw = unloadingRes?['unloading_date'] as String?;
        if (raw != null) unloading = DateTime.tryParse(raw);
      }
      final detentionDays = calculateDetentionDays(reportingDate, unloading);

      await _client
          .from(SupabaseConstants.tableTickets)
          .update({
            'reporting_date': reportingDate.toUtc().toIso8601String(),
            if (detentionDays != null) 'retention_days': detentionDays,
          })
          .eq('ticket_id', ticketId);
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
      await _client
          .from(SupabaseConstants.tableTickets)
          .update({'challan_urls': challanUrls})
          .eq('ticket_id', ticketId);
    } catch (e) {
      rethrow;
    }
  }

  // GET ALL TICKETS FOR A VEHICLE (for monthly report)
  Future<List<TicketModel>> getTicketsForVehicle({
    required String vehicleNumber,
    required String companyCode,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      // First get vehicle ID
      final vehicleRes = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('id')
          .eq('vehicle_number', vehicleNumber)
          .eq('company_code', companyCode)
          .maybeSingle();

      if (vehicleRes == null) return [];

      final response = await _client
          .from(SupabaseConstants.tableTickets)
          .select(_cols)
          .eq('vehicle_id', vehicleRes['id'])
          .eq('company_code', companyCode)
          .eq('status', 'completed')
          .gte('completed_at', fromDate.toUtc().toIso8601String())
          .lte('completed_at', toDate.toUtc().toIso8601String())
          .order('completed_at', ascending: false);

      return (response as List)
          .map((j) => TicketModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

class ReportRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> getOverallSummary(String companyCode) async {
    try {
      final vehiclesRes = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('id, status')
          .eq('company_code', companyCode);
      
      final List vehiclesList = vehiclesRes as List;
      final totalVehicles = vehiclesList.length;
      final usedVehicles = vehiclesList.where((v) => v['status'] != 'available').length;

      final ticketsRes = await _client
          .from(SupabaseConstants.tableTickets)
          .select('ticket_id, status')
          .eq('company_code', companyCode);
      
      final List ticketsList = ticketsRes as List;
      final totalTrips = ticketsList.length;
      final inTransit = ticketsList.where((t) => t['status'] == 'in_transit').length;
      final completed = ticketsList.where((t) => t['status'] == 'completed').length;

      final List<String> ticketIds = ticketsList.map((t) => t['ticket_id'] as String).toList();

      double totalLoadingWeight = 0;
      double totalUnloadingWeight = 0;
      double totalShortageWeight = 0;

      if (ticketIds.isNotEmpty) {
        final loadingWeightRes = await _client
            .from(SupabaseConstants.tableLoadingStatus)
            .select('loading_weight_kgs')
            .inFilter('ticket_id', ticketIds);

        final unloadingRes = await _client
            .from(SupabaseConstants.tableUnloadingStatus)
            .select('unloading_weight_kgs, shortage_kgs')
            .inFilter('ticket_id', ticketIds);

        for (var row in (loadingWeightRes as List)) {
          totalLoadingWeight += (row['loading_weight_kgs'] as num).toDouble();
        }

        for (var row in (unloadingRes as List)) {
          totalUnloadingWeight += (row['unloading_weight_kgs'] as num).toDouble();
          totalShortageWeight += (row['shortage_kgs'] as num).toDouble();
        }
      }

      double utilization = totalVehicles > 0 ? (usedVehicles / totalVehicles) * 100 : 0;

      return {
        'totalTrips': totalTrips,
        'inTransit': inTransit,
        'completed': completed,
        'totalLoadingKgs': totalLoadingWeight,
        'totalUnloadingKgs': totalUnloadingWeight,
        'totalShortageKgs': totalShortageWeight,
        'utilization': utilization,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getVehicleWiseReport(String companyCode) async {
    try {
      final vehicles = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('vehicle_number')
          .eq('company_code', companyCode);

      List<Map<String, dynamic>> report = [];

      for (var v in (vehicles as List)) {
        final vehicleNumber = v['vehicle_number'] as String;

        final ticketsRes = await _client
            .from(SupabaseConstants.tableLoadingStatus)
            .select('ticket_id, loading_weight_kgs, creation_date')
            .eq('vehicle_number', vehicleNumber)
            .order('creation_date', ascending: false);

        final List ticketsList = ticketsRes as List;
        int tripCount = ticketsList.length;
        double totalLoading = 0;
        double totalUnloading = 0;
        double totalShortage = 0;
        String lastTrip = 'N/A';

        if (tripCount > 0) {
          lastTrip = ticketsList[0]['ticket_id'] as String;
          for (var t in ticketsList) {
            totalLoading += (t['loading_weight_kgs'] as num).toDouble();
            
            final unloadingRes = await _client
                .from(SupabaseConstants.tableUnloadingStatus)
                .select('unloading_weight_kgs, shortage_kgs')
                .eq('ticket_id', t['ticket_id'])
                .maybeSingle();
            
            if (unloadingRes != null) {
              totalUnloading += (unloadingRes['unloading_weight_kgs'] as num).toDouble();
              totalShortage += (unloadingRes['shortage_kgs'] as num).toDouble();
            }
          }
        }

        report.add({
          'vehicleNumber': vehicleNumber,
          'tripCount': tripCount,
          'loadingKgs': totalLoading,
          'unloadingKgs': totalUnloading,
          'shortageKgs': totalShortage,
          'lastTrip': lastTrip,
        });
      }

      return report;
    } catch (e) {
      rethrow;
    }
  }

  // GET VEHICLE MONTHLY REPORT
  Future<Map<String, dynamic>> getVehicleMonthlyReport({
    required String vehicleNumber,
    required String companyCode,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      // Get vehicle ID
      final vehicleRes = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('id')
          .eq('vehicle_number', vehicleNumber)
          .eq('company_code', companyCode)
          .maybeSingle();

      if (vehicleRes == null) return {};

      final vehicleId = vehicleRes['id'] as String;

      // Get completed tickets for this vehicle in date range
      final ticketsRes = await _client
          .from(SupabaseConstants.tableTickets)
          .select('ticket_id, assigned_at, completed_at, reporting_date, challan_urls, created_by, driver_user_id, retention_days')
          .eq('vehicle_id', vehicleId)
          .eq('company_code', companyCode)
          .eq('status', 'completed')
          .gte('completed_at', fromDate.toUtc().toIso8601String())
          .lte('completed_at', toDate.toUtc().toIso8601String())
          .order('completed_at', ascending: false);

      final List ticketsList = ticketsRes as List;
      int tripCount = ticketsList.length;
      double totalLoading = 0;
      double totalUnloading = 0;
      double totalShortage = 0;
      List<Map<String, dynamic>> tripDetails = [];

      for (var t in ticketsList) {
        final ticketId = t['ticket_id'] as String;
        
        final loadingRes = await _client
            .from(SupabaseConstants.tableLoadingStatus)
            .select('loading_weight_kgs')
            .eq('ticket_id', ticketId)
            .maybeSingle();
        
        final unloadingRes = await _client
            .from(SupabaseConstants.tableUnloadingStatus)
            .select('unloading_weight_kgs, shortage_kgs')
            .eq('ticket_id', ticketId)
            .maybeSingle();

        double loading = loadingRes != null ? (loadingRes['loading_weight_kgs'] as num).toDouble() : 0;
        double unloading = unloadingRes != null ? (unloadingRes['unloading_weight_kgs'] as num).toDouble() : 0;
        double shortage = unloadingRes != null ? (unloadingRes['shortage_kgs'] as num).toDouble() : 0;

        totalLoading += loading;
        totalUnloading += unloading;
        totalShortage += shortage;

        // Get full loading details for the report
        final fullLoadingRes = await _client
            .from(SupabaseConstants.tableLoadingStatus)
            .select('lr_number, journey_from, journey_to, consignee_name, product, driver_name, creation_date')
            .eq('ticket_id', ticketId)
            .maybeSingle();

        // Get full unloading details
        final fullUnloadingRes = await _client
            .from(SupabaseConstants.tableUnloadingStatus)
            .select('unloading_date')
            .eq('ticket_id', ticketId)
            .maybeSingle();

        tripDetails.add({
          'ticketId': ticketId,
          'assignedAt': t['assigned_at'],
          'completedAt': t['completed_at'],
          'reportingDate': t['reporting_date'],
          'challanUrls': t['challan_urls'],
          'driverUserId': t['driver_user_id'],
          'createdBy': t['created_by'],
          'detentionDays': t['retention_days'],
          'loadingKgs': loading,
          'unloadingKgs': unloading,
          'shortageKgs': shortage,
          // Full loading details
          'lrNumber': fullLoadingRes?['lr_number'],
          'journeyFrom': fullLoadingRes?['journey_from'],
          'journeyTo': fullLoadingRes?['journey_to'],
          'consigneeName': fullLoadingRes?['consignee_name'],
          'product': fullLoadingRes?['product'],
          'driverName': fullLoadingRes?['driver_name'],
          'loadingDate': fullLoadingRes?['creation_date'],
          // Full unloading details
          'unloadingDate': fullUnloadingRes?['unloading_date'],
        });
      }

      return {
        'vehicleNumber': vehicleNumber,
        'tripCount': tripCount,
        'totalLoadingKgs': totalLoading,
        'totalUnloadingKgs': totalUnloading,
        'totalShortageKgs': totalShortage,
        'tripDetails': tripDetails,
      };
    } catch (e) {
      rethrow;
    }
  }
}

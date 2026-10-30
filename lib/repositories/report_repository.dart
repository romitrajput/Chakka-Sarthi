import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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
      final inTransit = ticketsList.where((t) => t['status'] == 'in_transit' || t['status'] == 'assigned').length;
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

  /// Driver changes on a trip, oldest first, e.g.
  /// "Sreeraj Balu → Bhavesh Ola (in transit, 30 Oct 2026, 07:40 PM)".
  Future<List<String>> driverChangeLines(String ticketId) async {
    try {
      final logs = await _client
          .from(SupabaseConstants.tableTripReassignments)
          .select('old_driver_user_id, new_driver_user_id, reassigned_at, reassigned_at_stage')
          .eq('ticket_id', ticketId)
          .order('reassigned_at', ascending: true);
      final rows = (logs as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return [];
      final ids = <String>{
        for (final r in rows) ...[r['old_driver_user_id'] as String, r['new_driver_user_id'] as String],
      };
      final names = await _namesFor(ids);
      String stage(String? s) => switch (s) {
            'assigned' => 'before loading',
            'loading' => 'in transit',
            'unloading' => 'at unloading',
            _ => s ?? '',
          };
      return rows.map((r) {
        final at = DateTime.tryParse(r['reassigned_at'] as String? ?? '');
        final when = at == null
            ? ''
            : DateFormat('dd MMM yyyy, hh:mm a').format(at.toUtc().add(const Duration(hours: 5, minutes: 30)));
        return '${names[r['old_driver_user_id']] ?? r['old_driver_user_id']} → '
            '${names[r['new_driver_user_id']] ?? r['new_driver_user_id']} (${stage(r['reassigned_at_stage'] as String?)}${when.isEmpty ? '' : ', $when'})';
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, String>> _namesFor(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final users = await _client
        .from(SupabaseConstants.tableUsers)
        .select('user_id, full_name')
        .inFilter('user_id', userIds.toList());
    return {
      for (final u in (users as List).cast<Map<String, dynamic>>()) u['user_id'] as String: u['full_name'] as String,
    };
  }

  /// Every vehicle's report for the period, merged into one list (newest trips first).
  Future<List<Map<String, dynamic>>> getAllVehiclesTrips({
    required List<String> vehicleNumbers,
    required String companyCode,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (final v in vehicleNumbers) {
      final r = await getVehicleMonthlyReport(
        vehicleNumber: v, companyCode: companyCode, fromDate: fromDate, toDate: toDate);
      final trips = r['tripDetails'];
      if (trips is List) all.addAll(trips.cast<Map<String, dynamic>>());
    }
    all.sort((a, b) => (b['completedAt'] ?? '').toString().compareTo((a['completedAt'] ?? '').toString()));
    return all;
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

        // Get full unloading details ('*' so it also works before the unloaded_by column exists)
        final fullUnloadingRes = await _client
            .from(SupabaseConstants.tableUnloadingStatus)
            .select('*')
            .eq('ticket_id', ticketId)
            .maybeSingle();

        // Who loaded, who unloaded, and any driver changes in between
        final finalDriverId = t['driver_user_id'] as String?;
        final finalDriverName = finalDriverId == null ? null : (await _namesFor({finalDriverId}))[finalDriverId];
        final loadedBy = fullLoadingRes?['driver_name'] as String?;
        final unloadedBy = (fullUnloadingRes?['unloaded_by'] as String?) ?? finalDriverName;
        final driverChanges = await driverChangeLines(ticketId);

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
          'driverName': (loadedBy != null && unloadedBy != null && loadedBy != unloadedBy)
              ? '$loadedBy → $unloadedBy'
              : (unloadedBy ?? loadedBy),
          'loadedBy': loadedBy,
          'unloadedBy': unloadedBy,
          'driverChanges': driverChanges,
          'vehicleNumber': vehicleNumber,
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

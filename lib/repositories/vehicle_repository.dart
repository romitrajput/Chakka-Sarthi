import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/models/vehicle_model.dart';

class VehicleRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<VehicleModel>> getAvailableVehicles(String companyCode) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('id, vehicle_number, company_code, status, maintenance_reason, maintenance_from, maintenance_expected_return, created_at')
          .eq('company_code', companyCode)
          .eq('status', 'available')
          .order('vehicle_number');

      return (response as List).map((json) => VehicleModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<VehicleModel>> getAllVehicles(String companyCode) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('id, vehicle_number, company_code, status, maintenance_reason, maintenance_from, maintenance_expected_return, created_at')
          .eq('company_code', companyCode)
          .order('vehicle_number');

      return (response as List).map((json) => VehicleModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateVehicleStatus({
    required String vehicleId,
    required String status,
    String? maintenanceReason,
    DateTime? maintenanceFrom,
    DateTime? maintenanceExpectedReturn,
  }) async {
    try {
      await _client.from(SupabaseConstants.tableVehicles).update({
        'status': status,
        'maintenance_reason': maintenanceReason,
        'maintenance_from': maintenanceFrom?.toIso8601String(),
        'maintenance_expected_return': maintenanceExpectedReturn?.toIso8601String(),
      }).eq('id', vehicleId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addVehicle({
    required String vehicleNumber,
    required String companyCode,
  }) async {
    try {
      await _client.from(SupabaseConstants.tableVehicles).insert({
        'vehicle_number': vehicleNumber.toUpperCase(),
        'company_code': companyCode,
        'status': 'available',
      });
    } catch (e) {
      rethrow;
    }
  }

  // BULK INSERT VEHICLES (for Excel/CSV import)
  Future<int> bulkInsertVehicles({
    required List<String> vehicleNumbers,
    required String companyCode,
  }) async {
    try {
      int insertedCount = 0;
      
      for (final number in vehicleNumbers) {
        final trimmed = number.trim().toUpperCase();
        if (trimmed.isEmpty) continue;
        
        // Check if vehicle already exists
        final existing = await _client
            .from(SupabaseConstants.tableVehicles)
            .select('id')
            .eq('vehicle_number', trimmed)
            .eq('company_code', companyCode)
            .maybeSingle();
        
        if (existing == null) {
          await _client.from(SupabaseConstants.tableVehicles).insert({
            'vehicle_number': trimmed,
            'company_code': companyCode,
            'status': 'available',
          });
          insertedCount++;
        }
      }
      
      return insertedCount;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getAvailableCount(String companyCode) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('id')
          .eq('company_code', companyCode)
          .eq('status', 'available');
      
      return (response as List).length;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getMaintenanceCount(String companyCode) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('id')
          .eq('company_code', companyCode)
          .eq('status', 'maintenance');
      
      return (response as List).length;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _client
          .from(SupabaseConstants.tableVehicles)
          .delete()
          .eq('id', vehicleId);
    } catch (e) {
      rethrow;
    }
  }

  // GET ALL VEHICLE NUMBERS (for monthly report dropdown)
  Future<List<String>> getAllVehicleNumbers(String companyCode) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableVehicles)
          .select('vehicle_number')
          .eq('company_code', companyCode)
          .order('vehicle_number');

      return (response as List)
          .map((v) => v['vehicle_number'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/models/loading_status_model.dart';
import 'package:sanjay_roadlines_fleet/models/unloading_status_model.dart';
import 'package:flutter/foundation.dart';

class LoadingUnloadingRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> submitLoadingStatus(LoadingStatusModel model) async {
    try {
      // Check if already submitted — prevent duplicate
      final existing = await _client
          .from(SupabaseConstants.tableLoadingStatus)
          .select('id')
          .eq('ticket_id', model.ticketId)
          .limit(1);

      if ((existing as List).isNotEmpty) {
        throw Exception("Loading already submitted");
      }

      await _client
          .from(SupabaseConstants.tableLoadingStatus)
          .insert(model.toJson());

      await _client
          .from(SupabaseConstants.tableTickets)
          .update({'status': 'in_transit'})
          .eq('ticket_id', model.ticketId);
    } catch (e) {
      rethrow;
    }
  }

  Future<LoadingStatusModel?> getLoadingStatus(String ticketId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLoadingStatus)
          .select('id, ticket_id, vehicle_number, driver_name, lr_number, journey_from, journey_to, consignee_name, product, loading_weight_kgs, creation_date, submitted_at')
          .eq('ticket_id', ticketId)
          .maybeSingle();

      if (response == null) return null;
      return LoadingStatusModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitUnloadingStatus({
    required UnloadingStatusModel unloadingStatus,
    required String vehicleId,
    required Uint8List pdfBytes,
    required String companyCode,
  }) async {
    try {
      // Verify loading exists
      final loading = await getLoadingStatus(unloadingStatus.ticketId);
      if (loading == null) {
        throw Exception('Loading status must be submitted first');
      }

      // Check if unloading already submitted
      final existingUnloading = await _client
          .from(SupabaseConstants.tableUnloadingStatus)
          .select('id')
          .eq('ticket_id', unloadingStatus.ticketId)
          .maybeSingle();

      if (existingUnloading != null) {
        throw Exception('Unloading status already submitted for this ticket');
      }

      // Insert unloading
      await _client
          .from(SupabaseConstants.tableUnloadingStatus)
          .insert(unloadingStatus.toJson());

      // Upload PDF
      String? pdfUrl;
      try {
        final fileName = "${unloadingStatus.ticketId}_report.pdf";
        final path = "$companyCode/$fileName";

        await _client.storage
            .from(SupabaseConstants.bucketTripDocuments)
            .uploadBinary(
          path,
          pdfBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

        pdfUrl = _client.storage
            .from(SupabaseConstants.bucketTripDocuments)
            .getPublicUrl(path);
      } catch (e) {
        debugPrint("UPLOAD ERROR: $e");
        pdfUrl = null;
        rethrow;
      }

      // Complete ticket
      await _client.from(SupabaseConstants.tableTickets).update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'pdf_url': pdfUrl,
      }).eq('ticket_id', unloadingStatus.ticketId);

      // Free vehicle
      await _client
          .from(SupabaseConstants.tableVehicles)
          .update({'status': 'available'})
          .eq('id', vehicleId);
    } catch (e) {
      rethrow;
    }
  }

  Future<UnloadingStatusModel?> getUnloadingStatus(String ticketId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUnloadingStatus)
          .select('id, ticket_id, unloading_weight_kgs, unloading_date, shortage_kgs, submitted_at')
          .eq('ticket_id', ticketId)
          .maybeSingle();

      if (response == null) return null;
      return UnloadingStatusModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // UPLOAD CHALLAN/DOCUMENT IMAGE
  Future<String> uploadChallanDocument({
    required String ticketId,
    required String companyCode,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final path = '$companyCode/$ticketId/$fileName';

      await _client.storage
          .from(SupabaseConstants.bucketChallanDocuments)
          .uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final url = _client.storage
          .from(SupabaseConstants.bucketChallanDocuments)
          .getPublicUrl(path);

      return url;
    } catch (e) {
      rethrow;
    }
  }

  // GET CHALLAN URLS FOR A TICKET
  Future<List<String>> getChallanUrls(String ticketId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableTickets)
          .select('challan_urls')
          .eq('ticket_id', ticketId)
          .maybeSingle();

      if (response == null || response['challan_urls'] == null) return [];
      return List<String>.from(response['challan_urls'] as List);
    } catch (e) {
      return [];
    }
  }
}

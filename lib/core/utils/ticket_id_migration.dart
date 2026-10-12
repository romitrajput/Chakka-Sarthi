import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

/// Migration utility to update existing ticket IDs from old format (YYYYMMDD)
/// to new format (DDMMYYYY).
/// 
/// Old format: SRL - 20260814-001 or SRL 20260814-001
/// New format: SRL 14082026-001
class TicketIdMigration {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Convert a ticket ID from old format to new format
  /// Returns null if the ID is already in new format or cannot be parsed
  static String? convertToNewFormat(String oldTicketId) {
    // Match pattern: SRL YYYYMMDD-XXX or SRL - YYYYMMDD-XXX
    final RegExp oldPattern = RegExp(r'SRL\s*-?\s*(\d{8})-(\d+)');
    final match = oldPattern.firstMatch(oldTicketId);
    
    if (match == null) return null;
    
    final dateStr = match.group(1)!; // YYYYMMDD
    final sequence = match.group(2)!; // 001, 002, etc.
    
    // Check if already in DDMMYYYY format (first 2 digits > 12 = invalid month = likely DDMM)
    final firstTwo = int.tryParse(dateStr.substring(0, 2)) ?? 0;
    final monthPart = int.tryParse(dateStr.substring(4, 6)) ?? 0;
    
    // If month part > 12, it's likely already DDMMYYYY or invalid
    if (monthPart > 12) return null;
    
    // Convert YYYYMMDD to DDMMYYYY
    final year = dateStr.substring(0, 4);
    final month = dateStr.substring(4, 6);
    final day = dateStr.substring(6, 8);
    
    final newDateStr = '$day$month$year';
    return 'SRL $newDateStr-$sequence';
  }

  /// Migrate all tickets with old format to new format
  /// Returns the number of tickets migrated
  static Future<int> migrateAllTickets() async {
    int migratedCount = 0;
    
    try {
      // Fetch all tickets
      final response = await _client
          .from(SupabaseConstants.tableTickets)
          .select('id, ticket_id');
      
      final tickets = response as List;
      
      for (var ticket in tickets) {
        final oldTicketId = ticket['ticket_id'] as String;
        final newTicketId = convertToNewFormat(oldTicketId);
        
        if (newTicketId != null && newTicketId != oldTicketId) {
          // Update the ticket ID
          await _client
              .from(SupabaseConstants.tableTickets)
              .update({'ticket_id': newTicketId})
              .eq('id', ticket['id']);
          
          migratedCount++;
          print('Migrated: $oldTicketId → $newTicketId');
        }
      }
      
      print('Migration complete. $migratedCount tickets updated.');
      return migratedCount;
    } catch (e) {
      print('Migration error: $e');
      rethrow;
    }
  }

  /// Check how many tickets need migration (dry run)
  static Future<List<Map<String, String>>> previewMigration() async {
    List<Map<String, String>> changes = [];
    
    try {
      final response = await _client
          .from(SupabaseConstants.tableTickets)
          .select('id, ticket_id');
      
      final tickets = response as List;
      
      for (var ticket in tickets) {
        final oldTicketId = ticket['ticket_id'] as String;
        final newTicketId = convertToNewFormat(oldTicketId);
        
        if (newTicketId != null && newTicketId != oldTicketId) {
          changes.add({
            'old': oldTicketId,
            'new': newTicketId,
          });
        }
      }
      
      return changes;
    } catch (e) {
      print('Preview error: $e');
      rethrow;
    }
  }
}

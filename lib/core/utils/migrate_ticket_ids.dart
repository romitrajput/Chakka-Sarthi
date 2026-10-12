import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

/// Preview and migrate ticket IDs from YYYYMMDD to DDMMYYYY format
void main() async {
  
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    publishableKey: SupabaseConstants.supabaseAnonKey,
  );

  final client = Supabase.instance.client;

  print('=== Ticket ID Migration: YYYYMMDD → DDMMYYYY ===\n');

  // Fetch all tickets
  final response = await client
      .from(SupabaseConstants.tableTickets)
      .select('id, ticket_id');

  final tickets = response as List;
  print('Total tickets found: ${tickets.length}\n');

  int migratedCount = 0;

  for (var ticket in tickets) {
    final oldTicketId = ticket['ticket_id'] as String;
    final newTicketId = _convertToNewFormat(oldTicketId);

    if (newTicketId != null && newTicketId != oldTicketId) {
      print('MIGRATING: $oldTicketId → $newTicketId');

      await client
          .from(SupabaseConstants.tableTickets)
          .update({'ticket_id': newTicketId})
          .eq('id', ticket['id']);

      migratedCount++;
    } else {
      print('SKIP (already correct): $oldTicketId');
    }
  }

  print('\n=== Migration Complete ===');
  print('Tickets migrated: $migratedCount');
  print('Tickets unchanged: ${tickets.length - migratedCount}');
}

String? _convertToNewFormat(String oldTicketId) {
  // Match patterns:
  // SRL YYYYMMDD-XXX (old)
  // SRL - YYYYMMDD-XXX (old with dash)
  // SRL DDMMYYYY-XXX (new - skip)
  final RegExp oldPattern = RegExp(r'SRL\s*-?\s*(\d{8})-(\d+)');
  final match = oldPattern.firstMatch(oldTicketId);

  if (match == null) return null;

  final dateStr = match.group(1)!;
  final sequence = match.group(2)!;

  // Check if first 4 digits look like a year (2020-2099)
  final firstFour = int.tryParse(dateStr.substring(0, 4)) ?? 0;
  final lastFour = int.tryParse(dateStr.substring(4, 8)) ?? 0;

  // If first 4 digits are a year (2020-2099), it's YYYYMMDD → convert to DDMMYYYY
  if (firstFour >= 2020 && firstFour <= 2099) {
    final year = dateStr.substring(0, 4);
    final month = dateStr.substring(4, 6);
    final day = dateStr.substring(6, 8);
    return 'SRL $day$month$year-$sequence';
  }

  // Otherwise, it's likely already DDMMYYYY or unknown format - skip
  return null;
}

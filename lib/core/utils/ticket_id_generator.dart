import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

class TicketIdGenerator {
  /// Generates Ticket ID in format: SRL DDMMYYYY-001
  /// Example: SRL 30082026-001
  static Future<String> generate(String companyCode) async {
    final now = DateTime.now();
    final dateStr = DateFormat('ddMMyyyy').format(now);
    final dayPrefix = 'SRL $dateStr-';

    try {
      final response = await Supabase.instance.client
          .from(SupabaseConstants.tableTickets)
          .select('ticket_id')
          .like('ticket_id', '$dayPrefix%')
          .order('ticket_id', ascending: false)
          .limit(1)
          .maybeSingle();

      int nextSequence = 1;
      if (response != null) {
        final lastTicketId = response['ticket_id'] as String;
        final parts = lastTicketId.split('-');
        if (parts.length >= 2) {
          nextSequence = (int.tryParse(parts.last) ?? 0) + 1;
        }
      }

      final sequenceStr = nextSequence.toString().padLeft(3, '0');
      return '$dayPrefix$sequenceStr';
    } catch (e) {
      return '${dayPrefix}001';
    }
  }
}

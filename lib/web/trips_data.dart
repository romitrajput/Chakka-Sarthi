import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/ticket_repository.dart';

/// One line of the website's trips table.
class TripRow {
  TripRow({required this.ticket, required this.vehicleNumber, this.from, this.to});
  final TicketModel ticket;
  final String vehicleNumber;
  final String? from;
  final String? to;

  String get route => (from == null && to == null) ? '—' : '${from ?? '?'} → ${to ?? '?'}';
}

/// All trips of the company (assigned, in transit and completed), newest first.
final allTripsProvider = FutureProvider<List<TripRow>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final repo = TicketRepository();
  final client = Supabase.instance.client;

  final results = await Future.wait([
    repo.getAllActiveTickets(user.companyCode),
    repo.getCompletedTickets(user.companyCode),
  ]);
  final tickets = [...results[0], ...results[1]]
    ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

  final vehicles = await client
      .from(SupabaseConstants.tableVehicles)
      .select('id, vehicle_number')
      .eq('company_code', user.companyCode);
  final vehicleNo = {
    for (final v in (vehicles as List).cast<Map<String, dynamic>>()) '${v['id']}': '${v['vehicle_number']}',
  };

  // Routes come from the loading forms (only this company's rows are visible)
  final loading = await client.from(SupabaseConstants.tableLoadingStatus).select('ticket_id, journey_from, journey_to');
  final routes = {
    for (final l in (loading as List).cast<Map<String, dynamic>>()) '${l['ticket_id']}': l,
  };

  return [
    for (final t in tickets)
      TripRow(
        ticket: t,
        vehicleNumber: vehicleNo[t.vehicleId] ?? '—',
        from: routes[t.ticketId]?['journey_from'] as String?,
        to: routes[t.ticketId]?['journey_to'] as String?,
      ),
  ];
});

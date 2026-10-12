import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';

final vehicleNumberProvider = FutureProvider.family<String, String>((
  ref,
  vehicleId,
) async {
  final repo = ref.watch(ticketRepositoryProvider);
  return await repo.getVehicleNumber(vehicleId);
});

class AssignedTicketScreen extends ConsumerWidget {
  const AssignedTicketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketState = ref.watch(ticketStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Assigned Tickets"),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ticketStateProvider.future),
        child: ticketState.when(
          data: (tickets) {
            final activeTickets = tickets
                .where(
                  (t) => t.status == 'assigned' || t.status == 'in_transit',
                )
                .toList();

            if (activeTickets.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_late_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No assigned trips",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: activeTickets.length,
              itemBuilder: (context, index) {
                final ticket = activeTickets[index];
                return _TicketListItem(ticket: ticket);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text("Error: $err")),
        ),
      ),
    );
  }
}

class _TicketListItem extends ConsumerWidget {
  final TicketModel ticket;
  const _TicketListItem({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleNumberAsync = ref.watch(
      vehicleNumberProvider(ticket.vehicleId),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/driver/ticket-detail/${ticket.ticketId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ticket.ticketId,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StatusChip(status: ticket.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 18,
                    color: AppColors.primaryMid,
                  ),
                  const SizedBox(width: 8),
                  vehicleNumberAsync.when(
                    data: (number) => Text(
                      number,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => Text(
                      ticket.vehicleId,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.primaryMid,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ticket.formattedAssignedAt,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

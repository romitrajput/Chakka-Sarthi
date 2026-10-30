import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

// Vehicle number provider
final assignedVehicleNumberProvider =
    FutureProvider.family<String, String>((ref, vehicleId) async {
  return ref.watch(ticketRepositoryProvider).getVehicleNumber(vehicleId);
});

class AssignedTicketScreen extends ConsumerWidget {
  const AssignedTicketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketState = ref.watch(ticketStateProvider);
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(currentLocale.languageCode == 'hi' ? 'सौंपी गई यात्राएं' : 'Assigned Trips')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ticketStateProvider),
        child: ticketState.when(
          data: (tickets) {
            final active = tickets
                .where((t) =>
                    t.status == 'assigned' || t.status == 'in_transit')
                .toList();

            if (active.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.28),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_outlined,
                            size: 72, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          currentLocale.languageCode == 'hi' ? 'कोई सौंपी गई यात्रा नहीं' : 'No assigned trips',
                          style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentLocale.languageCode == 'hi' ? 'रिफ्रेश करने के लिए नीचे खींचें' : 'Pull down to refresh',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: active.length,
              itemBuilder: (context, index) =>
                  _TicketCard(ticket: active[index]),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.errorRed),
                const SizedBox(height: 12),
                Text('Error: $err',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(ticketStateProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  final TicketModel ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync =
        ref.watch(assignedVehicleNumberProvider(ticket.vehicleId));
    final currentLocale = ref.watch(languageProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () =>
            context.push('/driver/ticket-detail/${ticket.ticketId}'),
        borderRadius: BorderRadius.circular(14),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  StatusChip(status: ticket.status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 18, color: AppColors.primaryMid),
                  const SizedBox(width: 8),
                  vehicleAsync.when(
                    data: (number) => Text(number,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    loading: () => const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryMid)),
                    error: (_, __) => const Text('—',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    ticket.formattedAssignedAt,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentLocale.languageCode == 'hi' ? 'विवरण देखें' : 'View Details',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryMid,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios,
                        size: 12, color: AppColors.primaryMid),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

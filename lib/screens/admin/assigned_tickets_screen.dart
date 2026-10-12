import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/ticket_repository.dart';
import 'package:sanjay_roadlines_fleet/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

final reassignDriversProvider = FutureProvider<List<UserModel>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];

  final response = await Supabase.instance.client
      .from(SupabaseConstants.tableUsers)
      .select('id, user_id, full_name, mobile, role, company_code, mpin_hash, is_first_login, is_active, sequential_num, created_at')
      .eq('company_code', user.companyCode)
      .eq('role', 'driver')
      .eq('is_active', true)
      .order('full_name');

  return (response as List).map((json) => UserModel.fromJson(json as Map<String, dynamic>)).toList();
});

class AdminAssignedTicketsScreen extends ConsumerStatefulWidget {
  const AdminAssignedTicketsScreen({super.key});

  @override
  ConsumerState<AdminAssignedTicketsScreen> createState() =>
      _AdminAssignedTicketsScreenState();
}

class _AdminAssignedTicketsScreenState
    extends ConsumerState<AdminAssignedTicketsScreen> {
  final Map<String, String> _vehicleNumberCache = {};

  Future<String> _getVehicleNumber(String vehicleId) async {
    if (_vehicleNumberCache.containsKey(vehicleId)) {
      return _vehicleNumberCache[vehicleId]!;
    }
    try {
      final ticketRepo = TicketRepository();
      final number = await ticketRepo.getVehicleNumber(vehicleId);
      _vehicleNumberCache[vehicleId] = number;
      return number;
    } catch (e) {
      return vehicleId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTicketsAsync = ref.watch(allActiveTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Re-assign Driver'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allActiveTicketsProvider),
        child: activeTicketsAsync.when(
          data: (tickets) {
            if (tickets.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.28),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.swap_horiz_outlined,
                            size: 72,
                            color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No active tickets',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tickets appear here when assigned or in transit',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
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
              itemCount: tickets.length,
              itemBuilder: (context, index) =>
                  _ReassignTicketCard(
                    ticket: tickets[index],
                    vehicleNumberCache: _vehicleNumberCache,
                    getVehicleNumber: _getVehicleNumber,
                    onReassign: () => _showReassignDialog(tickets[index]),
                  ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
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
                  onPressed: () => ref.invalidate(allActiveTicketsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStageLabel(String stage) {
    switch (stage) {
      case 'assigned':
        return 'Pre-Loading (Assigned)';
      case 'loading':
        return 'In Transit (Loading Done)';
      case 'unloading':
        return 'Unloading Stage';
      case 'completed':
        return 'Completed';
      default:
        return stage.toUpperCase();
    }
  }

  void _showReassignDialog(TicketModel ticket) async {
    // Fetch drivers first before showing dialog
    List<UserModel> drivers = [];
    try {
      drivers = await ref.read(reassignDriversProvider.future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load drivers: $e'), backgroundColor: AppColors.errorRed),
        );
      }
      return;
    }

    if (!mounted) return;

    UserModel? selectedDriver;
    String? reason;
    final availableDrivers = drivers
        .where((d) => d.userId != ticket.driverUserId)
        .toList();

    final currentStage = ticket.currentStage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Re-assign Driver'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip: ${ticket.ticketId}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Driver: ${ticket.driverUserId}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              currentStage == 'assigned'
                                  ? Icons.assignment_outlined
                                  : currentStage == 'loading'
                                      ? Icons.local_shipping_outlined
                                      : Icons.task_alt,
                              size: 14,
                              color: AppColors.accentOrange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Stage: ${_getStageLabel(currentStage)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentOrange),
                            ),
                          ],
                        ),
                        if (ticket.reassignmentCount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.swap_horiz, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Reassigned ${ticket.reassignmentCount} time(s) before',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Select new driver
                  DropdownButtonFormField<UserModel>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select New Driver',
                      border: OutlineInputBorder(),
                    ),
                    items: availableDrivers.map((driver) {
                      return DropdownMenuItem(
                        value: driver,
                        child: Text(
                            '${driver.fullName} (${driver.userId})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedDriver = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Reason (optional)
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Driver unavailable',
                    ),
                    maxLines: 2,
                    onChanged: (v) => reason = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: selectedDriver == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _reassignTrip(ticket, selectedDriver!.userId, reason);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                ),
                child: const Text('REASSIGN'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _reassignTrip(
      TicketModel ticket, String newDriverUserId, String? reason) async {
    try {
      await ref.read(ticketStateProvider.notifier).reassignTicket(
            ticketId: ticket.ticketId,
            newDriverUserId: newDriverUserId,
            reason: reason,
            reassignedAtStage: ticket.currentStage,
          );

      // Send notification to the new driver
      try {
        final notifRepo = NotificationRepository();
        await notifRepo.sendNotification(
          targetUserId: newDriverUserId,
          title: 'Trip Reassigned',
          message:
              'Trip ${ticket.ticketId} has been reassigned to you. Stage: ${_getStageLabel(ticket.currentStage)}. Please check your assigned tickets.',
          ticketId: ticket.ticketId,
        );
      } catch (_) {
        // Background notification - don't block UI
      }

      // Refresh tickets
      ref.invalidate(allActiveTicketsProvider);
      ref.invalidate(assignedTicketsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip has been reassigned successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
}

class _ReassignTicketCard extends StatelessWidget {
  final TicketModel ticket;
  final Map<String, String> vehicleNumberCache;
  final Future<String> Function(String) getVehicleNumber;
  final VoidCallback onReassign;

  const _ReassignTicketCard({
    required this.ticket,
    required this.vehicleNumberCache,
    required this.getVehicleNumber,
    required this.onReassign,
  });

  String _getStageLabel(String stage) {
    switch (stage) {
      case 'assigned':
        return 'Pre-Loading';
      case 'loading':
        return 'In Transit';
      case 'unloading':
        return 'Unloading';
      case 'completed':
        return 'Completed';
      default:
        return stage.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = ticket.currentStage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                const SizedBox(width: 6),
                Expanded(
                  child: FutureBuilder<String>(
                    future: getVehicleNumber(ticket.vehicleId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Loading...',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Driver: ${ticket.driverUserId}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
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
            // Stage indicator
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  stage == 'assigned'
                      ? Icons.assignment_outlined
                      : stage == 'loading'
                          ? Icons.local_shipping_outlined
                          : Icons.task_alt,
                  size: 18,
                  color: AppColors.accentOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Stage: ${_getStageLabel(stage)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentOrange),
                ),
                if (ticket.reassignmentCount > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.inTransitBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Reassigned ×${ticket.reassignmentCount}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warningYellow),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            // REASSIGN BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReassign,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text(
                  'RE-ASSIGN DRIVER',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

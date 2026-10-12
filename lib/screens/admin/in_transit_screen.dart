import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';
import 'package:sanjay_roadlines_fleet/repositories/ticket_repository.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

class InTransitScreen extends ConsumerStatefulWidget {
  const InTransitScreen({super.key});

  @override
  ConsumerState<InTransitScreen> createState() => _InTransitScreenState();
}

class _InTransitScreenState extends ConsumerState<InTransitScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
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
    final ticketsAsync = ref.watch(ticketStateProvider);
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLocale.languageCode == 'hi' ? 'रास्ते में' : AppStrings.inTransit),
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: ticketsAsync.when(
              data: (tickets) {
                final filteredTickets = tickets.where((t) {
                  if (_fromDate != null && t.assignedAt.isBefore(_fromDate!)) return false;
                  if (_toDate != null && t.assignedAt.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
                  return true;
                }).toList();

                if (filteredTickets.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    _buildCountHeader(filteredTickets.length),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredTickets.length,
                        itemBuilder: (context, index) {
                          return _buildTicketCard(filteredTickets[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildDateChip(
              label: _fromDate == null ? 'From Date' : DateFormat('dd MMM yyyy').format(_fromDate!),
              onTap: () => _selectDate(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDateChip(
              label: _toDate == null ? 'To Date' : DateFormat('dd MMM yyyy').format(_toDate!),
              onTap: () => _selectDate(false),
            ),
          ),
          if (_fromDate != null || _toDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.errorRed),
              onPressed: () => setState(() {
                _fromDate = null;
                _toDate = null;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDateChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(Icons.calendar_today, size: 16),
      backgroundColor: AppColors.background,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    );
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Widget _buildCountHeader(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '$count trips in transit',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(TicketModel ticket) {
    return Card(
      child: InkWell(
        onTap: () => _showTripDetails(ticket),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  StatusChip(status: ticket.status),
                ],
              ),
              const Divider(height: 24),
              FutureBuilder<String>(
                future: _getVehicleNumber(ticket.vehicleId),
                builder: (context, snapshot) {
                  return _buildInfoRow(Icons.minor_crash, 'Vehicle', snapshot.data ?? 'Loading...');
                },
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, 'Driver', ticket.driverUserId),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.event, 'Assigned', ticket.formattedAssignedAt),
              // Show reassignment info
              if (ticket.reassignmentCount > 0) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.swap_horiz, 'Reassigned', '${ticket.reassignmentCount} time(s)'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label:', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            AppStrings.noTripsInTransit,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showTripDetails(TicketModel ticket) async {
    final loadingRepo = LoadingUnloadingRepository();
    final loadingStatus = await loadingRepo.getLoadingStatus(ticket.ticketId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Trip Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  if (loadingStatus != null) ...[
                    _buildDetailRow('LR Number', loadingStatus.lrNumber),
                    _buildDetailRow('From', loadingStatus.journeyFrom),
                    _buildDetailRow('To', loadingStatus.journeyTo),
                    _buildDetailRow('Consigner', loadingStatus.consigneeName),
                    _buildDetailRow('Product', loadingStatus.product),
                    _buildDetailRow('Loading Weight', '${loadingStatus.loadingWeightKgs} Kgs'),
                  ] else
                    const Center(child: Text('Loading details not yet submitted')),
                  

                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

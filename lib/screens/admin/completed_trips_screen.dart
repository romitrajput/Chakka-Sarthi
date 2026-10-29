import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/core/utils/pdf_generator.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';
import 'package:sanjay_roadlines_fleet/repositories/ticket_repository.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/reassignment_history.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

class CompletedTripsScreen extends ConsumerStatefulWidget {
  const CompletedTripsScreen({super.key});

  @override
  ConsumerState<CompletedTripsScreen> createState() =>
      _CompletedTripsScreenState();
}

class _CompletedTripsScreenState extends ConsumerState<CompletedTripsScreen> {
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
    final ticketsAsync = ref.watch(completedTicketsProvider);
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLocale.languageCode == 'hi' ? 'पूर्ण यात्राएं' : AppStrings.completedTrips),
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: ticketsAsync.when(
              data: (tickets) {
                final filteredTickets = tickets.where((t) {
                  if (t.completedAt == null) return false;
                  if (_fromDate != null && t.completedAt!.isBefore(_fromDate!)) return false;
                  if (_toDate != null &&
                      t.completedAt!.isAfter(
                        _toDate!.add(const Duration(days: 1)),
                      )) return false;
                  return true;
                }).toList();

                if (filteredTickets.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredTickets.length,
                  itemBuilder: (context, index) {
                    return _buildTicketCard(filteredTickets[index]);
                  },
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
            child: ActionChip(
              label: Text(
                _fromDate == null
                    ? 'From Date'
                    : DateFormat('dd MMM yyyy').format(_fromDate!),
              ),
              onPressed: () => _selectDate(true),
              avatar: const Icon(Icons.calendar_today, size: 16),
              backgroundColor: AppColors.background,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ActionChip(
              label: Text(
                _toDate == null
                    ? 'To Date'
                    : DateFormat('dd MMM yyyy').format(_toDate!),
              ),
              onPressed: () => _selectDate(false),
              avatar: const Icon(Icons.calendar_today, size: 16),
              backgroundColor: AppColors.background,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye, color: AppColors.primaryDark, size: 20),
                        onPressed: () => _showTripDetails(ticket),
                        tooltip: 'View Details',
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: AppColors.primaryDark, size: 20),
                        onPressed: () => _downloadReport(ticket),
                        tooltip: 'Export Report',
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              FutureBuilder<String>(
                future: _getVehicleNumber(ticket.vehicleId),
                builder: (context, snapshot) {
                  return _buildInfoRow(
                    Icons.minor_crash,
                    'Vehicle',
                    snapshot.data ?? 'Loading...',
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, 'Driver', ticket.driverUserId),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.event_available, 'Assigned', ticket.formattedAssignedAt),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.event_note, 'Completed', ticket.formattedCompletedAt),
              if (ticket.detentionDays != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.schedule, 'Detention', '${ticket.detentionDays} days'),
              ],
              if (ticket.challanUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.image, 'Challans', '${ticket.challanUrls.length} image(s)'),
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
        Text(
          '$label:',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            AppStrings.noCompletedTrips,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showTripDetails(TicketModel ticket) async {
    final loadingRepo = LoadingUnloadingRepository();
    final loadingStatus = await loadingRepo.getLoadingStatus(ticket.ticketId);
    final unloadingStatus = await loadingRepo.getUnloadingStatus(ticket.ticketId);
    final vehicleNumber = await _getVehicleNumber(ticket.vehicleId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
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
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trip Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Trip Info
                  _buildDetailRow('Ticket ID', ticket.ticketId),
                  _buildDetailRow('Vehicle', vehicleNumber),
                  _buildDetailRow('Driver', ticket.driverUserId),
                  _buildDetailRow('Status', ticket.status.toUpperCase()),
                  _buildDetailRow('Assigned', ticket.formattedAssignedAt),
                  _buildDetailRow('Completed', ticket.formattedCompletedAt),

                  if (ticket.reportingDate != null)
                    _buildDetailRow('Reporting Date', DateFormat('dd MMM yyyy').format(ticket.reportingDate!)),
                  if (ticket.detentionDays != null)
                    _buildDetailRow('Detention Days', '${ticket.detentionDays} days'),

                  if (ticket.reassignmentCount > 0) ...[
                    const Divider(height: 32),
                    Text('Driver history (re-assigned ${ticket.reassignmentCount}×)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ReassignmentHistory(ticketId: ticket.ticketId),
                  ],

                  if (loadingStatus != null) ...[
                    const Divider(height: 32),
                    const Text('Loading Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildDetailRow('LR Number', loadingStatus.lrNumber),
                    _buildDetailRow('From', loadingStatus.journeyFrom),
                    _buildDetailRow('To', loadingStatus.journeyTo),
                    _buildDetailRow('Consigner', loadingStatus.consigneeName),
                    _buildDetailRow('Product', loadingStatus.product),
                    _buildDetailRow('Loading Weight', '${loadingStatus.loadingWeightKgs} Kgs'),
                  ],

                  if (unloadingStatus != null) ...[
                    const Divider(height: 32),
                    const Text('Unloading Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildDetailRow('Unloading Weight', '${unloadingStatus.unloadingWeightKgs} Kgs'),
                    _buildDetailRow('Shortage', '${unloadingStatus.shortageKgs} Kgs'),
                  ],

                  // Challan Images
                  if (ticket.challanUrls.isNotEmpty) ...[
                    const Divider(height: 32),
                    const Text('Challan Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: ticket.challanUrls.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _viewFullImage(context, ticket.challanUrls[index]),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ticket.challanUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Download PDF button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadReport(ticket);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('EXPORT REPORT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _viewFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Failed to load image'),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _downloadReport(TicketModel ticket) async {
    try {
      final loadingRepo = LoadingUnloadingRepository();
      final loading = await loadingRepo.getLoadingStatus(ticket.ticketId);
      final unloading = await loadingRepo.getUnloadingStatus(ticket.ticketId);

      if (loading == null || unloading == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip data incomplete'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }

      final pdfBytes = await PdfGenerator.generateTripPdf(
        ticket: ticket,
        loading: loading,
        unloading: unloading,
        companyName: await currentBusinessName(ref),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Trip_Report_${ticket.ticketId}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/core/utils/pdf_generator.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/report_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';
import 'package:sanjay_roadlines_fleet/repositories/ticket_repository.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedVehicleNumber;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLocale.languageCode == 'hi' ? 'डैशबोर्ड' : AppStrings.reports),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Vehicle-wise'),
            Tab(text: 'Export'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverallSummaryTab(),
                _buildVehicleWiseTab(),
                _buildExportReportTab(),
              ],
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
              label: Text(_fromDate == null ? 'From Date' : DateFormat('dd MMM yyyy').format(_fromDate!)),
              onPressed: () => _selectDate(true),
              avatar: const Icon(Icons.calendar_today, size: 16),
              backgroundColor: AppColors.background,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ActionChip(
              label: Text(_toDate == null ? 'To Date' : DateFormat('dd MMM yyyy').format(_toDate!)),
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

  // ===== TRIP SUMMARY TAB (Interactive) =====
  Widget _buildOverallSummaryTab() {
    final summaryAsync = ref.watch(reportStateProvider);
    final user = ref.watch(authStateProvider).value;

    return summaryAsync.when(
      data: (summary) {
        if (summary.isEmpty) return const Center(child: Text('No data available'));

        // Company info header
        final companyInfo = _buildCompanyInfoHeader(user);

        final items = [
          _SummaryItem('Total Trips', summary['totalTrips']?.toString() ?? '0', Icons.assignment, 'totalTrips'),
          _SummaryItem('In Transit', summary['inTransit']?.toString() ?? '0', Icons.local_shipping, 'inTransit'),
          _SummaryItem('Completed', summary['completed']?.toString() ?? '0', Icons.task_alt, 'completed'),
          _SummaryItem('Total Loading (Kgs)', (summary['totalLoadingKgs'] as double?)?.toStringAsFixed(2) ?? '0.00', Icons.add_circle_outline, 'loading'),
          _SummaryItem('Total Unloading (Kgs)', (summary['totalUnloadingKgs'] as double?)?.toStringAsFixed(2) ?? '0.00', Icons.remove_circle_outline, 'unloading'),
          _SummaryItem('Total Shortage (Kgs)', (summary['totalShortageKgs'] as double?)?.toStringAsFixed(2) ?? '0.00', Icons.report_problem, 'shortage'),
          _SummaryItem('Utilization %', '${(summary['utilization'] as double?)?.toStringAsFixed(1) ?? '0.0'}%', Icons.pie_chart, 'utilization'),
        ];

        return Column(
          children: [
            companyInfo,
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildSummaryCard(items[index]);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSummaryCard(_SummaryItem item) {
    return InkWell(
      onTap: () => _onSummaryTap(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: AppColors.primaryDark, size: 24),
            const SizedBox(height: 12),
            Text(item.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(item.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primaryMid),
          ],
        ),
      ),
    );
  }

  void _onSummaryTap(_SummaryItem item) {
    if (item.type == 'totalTrips' || item.type == 'completed' || item.type == 'inTransit') {
      _showTripsList(item.type);
    } else if (item.type == 'shortage') {
      _showShortageDetails();
    }
  }

  void _showTripsList(String type) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final ticketRepo = TicketRepository();
      List<TicketModel> tickets;

      if (type == 'completed') {
        tickets = await ticketRepo.getCompletedTickets(user.companyCode);
      } else if (type == 'inTransit') {
        tickets = await ticketRepo.getInTransitTickets(user.companyCode);
      } else {
        final completed = await ticketRepo.getCompletedTickets(user.companyCode);
        final inTransit = await ticketRepo.getInTransitTickets(user.companyCode);
        tickets = [...completed, ...inTransit];
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('${tickets.length} Trips', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final t = tickets[index];
                      return ListTile(
                        leading: Icon(
                          t.status == 'completed' ? Icons.task_alt : Icons.local_shipping,
                          color: t.status == 'completed' ? AppColors.successGreen : AppColors.accentOrange,
                        ),
                        title: Text(t.ticketId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          'Assigned: ${t.formattedAssignedAt}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.status == 'completed' ? AppColors.completedBg : AppColors.inTransitBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(t.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  void _showShortageDetails() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final ticketRepo = TicketRepository();
      final completed = await ticketRepo.getCompletedTickets(user.companyCode);
      final loadingRepo = LoadingUnloadingRepository();

      List<Map<String, dynamic>> shortageData = [];
      for (var ticket in completed) {
        final unloading = await loadingRepo.getUnloadingStatus(ticket.ticketId);
        if (unloading != null && unloading.shortageKgs > 0) {
          shortageData.add({
            'ticket': ticket,
            'shortage': unloading.shortageKgs,
          });
        }
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Shortage Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: shortageData.isEmpty
                      ? const Center(child: Text('No shortage found'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: shortageData.length,
                          itemBuilder: (context, index) {
                            final data = shortageData[index];
                            final ticket = data['ticket'] as TicketModel;
                            final shortage = data['shortage'] as double;
                            return ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
                              title: Text(ticket.ticketId, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Completed: ${ticket.formattedCompletedAt}'),
                              trailing: Text(
                                '${shortage.toStringAsFixed(2)} Kgs',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.errorRed),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  // ===== VEHICLE-WISE TAB (Interactive) =====
  Widget _buildVehicleWiseTab() {
    final vehicleReportAsync = ref.watch(vehicleWiseReportProvider);

    return vehicleReportAsync.when(
      data: (report) {
        if (report.isEmpty) return const Center(child: Text('No vehicle data available'));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: report.length,
          itemBuilder: (context, index) {
            final v = report[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: InkWell(
                onTap: () => _showVehicleTripDetails(v['vehicleNumber'] as String? ?? ''),
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
                            v['vehicleNumber'] as String? ?? 'Unknown',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primaryMid),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildVerticalInfo('Trips', v['tripCount']?.toString() ?? '0'),
                          _buildVerticalInfo('Loading', (v['loadingKgs'] as double?)?.toStringAsFixed(2) ?? '0.00'),
                          _buildVerticalInfo('Unloading', (v['unloadingKgs'] as double?)?.toStringAsFixed(2) ?? '0.00'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildVerticalInfo('Shortage', (v['shortageKgs'] as double?)?.toStringAsFixed(2) ?? '0.00'),
                          _buildVerticalInfo('Last Trip', v['lastTrip'] as String? ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showVehicleTripDetails(String vehicleNumber) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final ticketRepo = TicketRepository();
      final fromDate = _fromDate ?? DateTime.now().subtract(const Duration(days: 365));
      final toDate = _toDate ?? DateTime.now();

      final tickets = await ticketRepo.getTicketsForVehicle(
        vehicleNumber: vehicleNumber,
        companyCode: user.companyCode,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(vehicleNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                Text('${tickets.length} trips', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final t = tickets[index];
                      return ExpansionTile(
                        leading: Icon(
                          t.status == 'completed' ? Icons.task_alt : Icons.local_shipping,
                          color: t.status == 'completed' ? AppColors.successGreen : AppColors.accentOrange,
                        ),
                        title: Text(t.ticketId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Assigned: ${t.formattedAssignedAt}', style: const TextStyle(fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Driver', t.driverUserId),
                                _buildDetailRow('Status', t.status.toUpperCase()),
                                if (t.completedAt != null)
                                  _buildDetailRow('Completed', t.formattedCompletedAt),
                                if (t.detentionDays != null)
                                  _buildDetailRow('Detention', '${t.detentionDays} days'),
                                if (t.challanUrls.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text('Challans:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 80,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: t.challanUrls.length,
                                      itemBuilder: (ctx, i) {
                                        return GestureDetector(
                                          onTap: () => _viewFullImage(context, t.challanUrls[i]),
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.divider),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(t.challanUrls[i], fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 20)),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  void _viewFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 64)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== EXPORT REPORT TAB (renamed from Download Report) =====
  Widget _buildExportReportTab() {
    final vehicleNumbersAsync = ref.watch(allVehicleNumbersProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle-wise Export Report',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a date range and vehicle to generate a consolidated PDF report.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          vehicleNumbersAsync.when(
            data: (vehicles) {
              return DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Vehicle',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedVehicleNumber,
                items: vehicles.map((v) {
                  return DropdownMenuItem(value: v, child: Text(v));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedVehicleNumber = value);
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedVehicleNumber == null ? null : _exportReport,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('EXPORT REPORT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport() async {
    if (_selectedVehicleNumber == null) return;

    final fromDate = _fromDate ?? DateTime.now().subtract(const Duration(days: 30));
    final toDate = _toDate ?? DateTime.now();

    try {
      final reportRepo = ref.read(reportRepositoryProvider);
      final report = await reportRepo.getVehicleMonthlyReport(
        vehicleNumber: _selectedVehicleNumber!,
        companyCode: ref.read(authStateProvider).value!.companyCode,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (report.isEmpty || report['tripDetails'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No trips found for this vehicle in the selected period'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }

      final pdfBytes = await PdfGenerator.generateConsolidatedReport(
        vehicleNumber: _selectedVehicleNumber!,
        tripDetails: List<Map<String, dynamic>>.from(report['tripDetails']),
        companyName: await currentBusinessName(ref),
        fromDate: fromDate,
        toDate: toDate,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Export_Report_${_selectedVehicleNumber}_${DateFormat('MMM_yyyy').format(fromDate)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Widget _buildCompanyInfoHeader(dynamic user) {
    return FutureBuilder(
      future: Supabase.instance.client
          .from(SupabaseConstants.tableCompanies)
          .select('company_name, state_code, company_code')
          .eq('company_code', user?.companyCode ?? '')
          .maybeSingle(),
      builder: (context, snapshot) {
        final company = snapshot.data;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company?['company_name'] as String? ?? 'Company',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          company?['state_code'] as String? ?? 'N/A',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.pin_drop_outlined, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          company?['company_code'] as String? ?? 'N/A',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final String type;

  _SummaryItem(this.label, this.value, this.icon, this.type);
}

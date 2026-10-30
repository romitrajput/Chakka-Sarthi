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
import 'package:sanjay_roadlines_fleet/providers/driver_names_provider.dart';
import 'package:sanjay_roadlines_fleet/core/utils/excel_exporter.dart';
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
    ref.watch(driverNamesProvider); // redraw when driver names load
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLocale.languageCode == 'hi' ? 'रिपोर्ट' : AppStrings.reports),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brandYellow,
          indicatorWeight: 3,
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
    final kg = NumberFormat('#,##0.00', 'en_IN');

    return summaryAsync.when(
      data: (summary) {
        if (summary.isEmpty) return const Center(child: Text('No data available'));

        final totalTrips = summary['totalTrips']?.toString() ?? '0';
        final inTransit = summary['inTransit']?.toString() ?? '0';
        final completed = summary['completed']?.toString() ?? '0';
        final loading = (summary['totalLoadingKgs'] as num?)?.toDouble() ?? 0;
        final unloading = (summary['totalUnloadingKgs'] as num?)?.toDouble() ?? 0;
        final shortage = (summary['totalShortageKgs'] as num?)?.toDouble() ?? 0;
        final utilization = ((summary['utilization'] as num?)?.toDouble() ?? 0).clamp(0, 100).toDouble();
        final shortagePct = loading > 0 ? shortage / loading * 100 : 0.0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildCompanyInfoHeader(user),
            const SizedBox(height: 18),

            // Trips
            const Text('Trips', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tripTile(_SummaryItem('Total', totalTrips, Icons.assignment_outlined, 'totalTrips'), AppColors.ink, AppColors.mist),
                  const SizedBox(width: 8),
                  _tripTile(_SummaryItem('In transit', inTransit, Icons.local_shipping_outlined, 'inTransit'), AppColors.warningYellow, AppColors.inTransitBg),
                  const SizedBox(width: 8),
                  _tripTile(_SummaryItem('Completed', completed, Icons.check_circle_outline, 'completed'), AppColors.successGreen, AppColors.availableBg),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Weights
            const Text('Load (kg)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _weightRow(Icons.upload_outlined, 'Total loading', kg.format(loading)),
                  const Divider(height: 1, indent: 56),
                  _weightRow(Icons.download_outlined, 'Total unloading', kg.format(unloading)),
                  const Divider(height: 1, indent: 56),
                  _weightRow(
                    Icons.warning_amber_rounded,
                    'Total shortage',
                    kg.format(shortage),
                    note: '${shortagePct.toStringAsFixed(2)}% of loading',
                    color: shortage > 0 ? AppColors.errorRed : AppColors.ink,
                    onTap: () => _onSummaryTap(_SummaryItem('Shortage', '', Icons.warning_amber_rounded, 'shortage')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Utilization
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Fleet utilization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      Text('${utilization.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: utilization / 100,
                      minHeight: 10,
                      backgroundColor: AppColors.mist,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandYellow),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Share of vehicles currently on a trip',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  /// One of three equal trip tiles; tap opens the trip list.
  Widget _tripTile(_SummaryItem item, Color color, Color tint) {
    return Expanded(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onSummaryTap(item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.icon, size: 18, color: color),
                ),
                const SizedBox(height: 10),
                Text(item.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weightRow(IconData icon, String label, String value,
      {String? note, Color color = AppColors.ink, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14)),
                  if (note != null)
                    Text(note, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            ],
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
            'trip': ticket,
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
                            final ticket = data['trip'] as TicketModel;
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
                                _buildDetailRow('Completed by', driverNameOf(ref, t.driverUserId)),
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
            'Pick a date range and a vehicle, or Export All for every vehicle. Download as PDF or Excel.',
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
                items: [
                  const DropdownMenuItem(
                    value: _allVehiclesKey,
                    child: Text('Export All (every vehicle)', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  ...vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                ],
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
              label: const Text('EXPORT PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandYellow,
                foregroundColor: AppColors.onBrandYellow,
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _selectedVehicleNumber == null || _exportingExcel ? null : _exportExcel,
              icon: _exportingExcel
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_chart_outlined),
              label: const Text('EXPORT EXCEL'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.ink, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _exportingExcel = false;

  /// Same data as the PDF, as an Excel sheet shared through WhatsApp, email, Drive etc.
  Future<void> _exportExcel() async {
    if (_selectedVehicleNumber == null) return;
    final fromDate = _fromDate ?? DateTime.now().subtract(const Duration(days: 30));
    final toDate = _toDate ?? DateTime.now();
    setState(() => _exportingExcel = true);
    try {
      final trips = await _loadExportTrips(fromDate, toDate);
      if (trips.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No trips found for this vehicle in the selected period'),
            backgroundColor: AppColors.errorRed,
          ));
        }
        return;
      }
      await ExcelExporter.shareVehicleReport(
        businessName: await currentBusinessName(ref),
        vehicleNumber: _isAllVehicles ? 'All vehicles' : _selectedVehicleNumber!,
        fromDate: fromDate,
        toDate: toDate,
        trips: trips,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating Excel file: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  static const String _allVehiclesKey = '__ALL_VEHICLES__';
  bool get _isAllVehicles => _selectedVehicleNumber == _allVehiclesKey;

  /// Trips for the chosen vehicle, or for every vehicle when "Export All" is chosen.
  Future<List<Map<String, dynamic>>> _loadExportTrips(DateTime fromDate, DateTime toDate) async {
    final repo = ref.read(reportRepositoryProvider);
    final companyCode = ref.read(authStateProvider).value!.companyCode;
    if (_isAllVehicles) {
      final vehicles = await ref.read(allVehicleNumbersProvider.future);
      return repo.getAllVehiclesTrips(
          vehicleNumbers: vehicles, companyCode: companyCode, fromDate: fromDate, toDate: toDate);
    }
    final report = await repo.getVehicleMonthlyReport(
      vehicleNumber: _selectedVehicleNumber!,
      companyCode: companyCode,
      fromDate: fromDate,
      toDate: toDate,
    );
    return report['tripDetails'] == null ? [] : List<Map<String, dynamic>>.from(report['tripDetails']);
  }

  Future<void> _exportReport() async {
    if (_selectedVehicleNumber == null) return;

    final fromDate = _fromDate ?? DateTime.now().subtract(const Duration(days: 30));
    final toDate = _toDate ?? DateTime.now();

    try {
      final trips = await _loadExportTrips(fromDate, toDate);
      if (trips.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No completed trips found in the selected period'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }

      final pdfBytes = await PdfGenerator.generateConsolidatedReport(
        vehicleNumber: _isAllVehicles ? 'All vehicles' : _selectedVehicleNumber!,
        tripDetails: trips,
        companyName: await currentBusinessName(ref),
        fromDate: fromDate,
        toDate: toDate,
        allVehicles: _isAllVehicles,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Export_Report_${_isAllVehicles ? 'All_Vehicles' : _selectedVehicleNumber}_${DateFormat('MMM_yyyy').format(fromDate)}',
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
    final businessName = ref.watch(businessNameProvider).value;
    return FutureBuilder(
      future: Supabase.instance.client
          .from(SupabaseConstants.tableCompanies)
          .select('company_name, state_code, company_code')
          .eq('company_code', user?.companyCode ?? '')
          .maybeSingle(),
      builder: (context, snapshot) {
        final company = snapshot.data;
        final name = businessName ?? company?['company_name'] as String? ?? 'Your business';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.brandYellow, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_rounded, color: AppColors.ink, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'State ${company?['state_code'] ?? '–'}  ·  Company code ${company?['company_code'] ?? '–'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD1D3D8)),
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

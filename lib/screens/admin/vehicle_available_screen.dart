import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';
import 'package:sanjay_roadlines_fleet/models/vehicle_model.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';

class VehicleAvailableScreen extends ConsumerStatefulWidget {
  const VehicleAvailableScreen({super.key});

  @override
  ConsumerState<VehicleAvailableScreen> createState() => _VehicleAvailableScreenState();
}

class _VehicleAvailableScreenState extends ConsumerState<VehicleAvailableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleState = ref.watch(vehicleStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'Maintenance'),
          ],
        ),
      ),
      body: vehicleState.when(
        data: (vehicles) {
          final available = vehicles.where((v) => v.status == 'available').toList();
          final maintenance = vehicles.where((v) => v.status == 'maintenance').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAvailableTab(available),
              _buildMaintenanceTab(maintenance),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAvailableTab(List<VehicleModel> vehicles) {
    if (vehicles.isEmpty) {
      return _buildEmptyState('No vehicles available', Icons.check_circle_outline);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCountHeader('${vehicles.length} vehicles available'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              return _buildAvailableCard(vehicles[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceTab(List<VehicleModel> vehicles) {
    if (vehicles.isEmpty) {
      return _buildEmptyState('No vehicles in maintenance', Icons.build_circle_outlined);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCountHeader('${vehicles.length} vehicles in maintenance'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              return _buildMaintenanceCard(vehicles[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCountHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildAvailableCard(VehicleModel vehicle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car, color: AppColors.successGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.vehicleNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const StatusChip(status: 'available'),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) => _handleAvailableAction(value, vehicle),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'maintenance',
                  child: Row(
                    children: [
                      Icon(Icons.build_circle_outlined, size: 18, color: AppColors.accentOrange),
                      SizedBox(width: 8),
                      Text('Send to Maintenance'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                      SizedBox(width: 8),
                      Text('Remove Vehicle', style: TextStyle(color: AppColors.errorRed)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceCard(VehicleModel vehicle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.build_circle_outlined, color: AppColors.accentOrange, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.vehicleNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const StatusChip(status: 'maintenance'),
                    ],
                  ),
                ),
              ],
            ),
            if (vehicle.maintenanceReason != null && vehicle.maintenanceReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.info_outline, 'Reason', vehicle.maintenanceReason!),
            ],
            if (vehicle.maintenanceFrom != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.calendar_today, 'From', DateFormat('dd MMM yyyy').format(vehicle.maintenanceFrom!)),
            ],
            if (vehicle.maintenanceExpectedReturn != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.event_repeat, 'Expected Return', DateFormat('dd MMM yyyy').format(vehicle.maintenanceExpectedReturn!)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markAvailable(vehicle),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark Available'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.successGreen,
                      side: const BorderSide(color: AppColors.successGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteVehicle(vehicle),
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                  tooltip: 'Remove Vehicle',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _handleAvailableAction(String action, VehicleModel vehicle) async {
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case 'maintenance':
        _showMaintenanceDialog(vehicle);
        break;
      case 'delete':
        _deleteVehicle(vehicle);
        break;
    }
  }

  void _showMaintenanceDialog(VehicleModel vehicle) {
    final reasonController = TextEditingController();
    DateTime? fromDate;
    DateTime? expectedReturn;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Send ${vehicle.vehicleNumber} to Maintenance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(fromDate == null ? 'Select Start Date *' : DateFormat('dd MMM yyyy').format(fromDate!)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateUtils.dateOnly(DateTime.now()), // no back-dated maintenance
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() => fromDate = date);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat),
                title: Text(expectedReturn == null ? 'Expected Return (Optional)' : DateFormat('dd MMM yyyy').format(expectedReturn!)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: fromDate ?? DateTime.now(),
                    firstDate: fromDate ?? DateUtils.dateOnly(DateTime.now()),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() => expectedReturn = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.isEmpty || fromDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields'), backgroundColor: AppColors.errorRed),
                  );
                  return;
                }
                Navigator.pop(context);
                await _sendToMaintenance(vehicle, reasonController.text, fromDate!, expectedReturn);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange,
                foregroundColor: Colors.white,),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendToMaintenance(VehicleModel vehicle, String reason, DateTime from, DateTime? expectedReturn) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(vehicleStateProvider.notifier).updateStatus(
        vehicleId: vehicle.id,
        status: 'maintenance',
        reason: reason,
        from: from,
        to: expectedReturn,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${vehicle.vehicleNumber} sent to maintenance'), backgroundColor: AppColors.successGreen),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  Future<void> _markAvailable(VehicleModel vehicle) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(vehicleStateProvider.notifier).updateStatus(
        vehicleId: vehicle.id,
        status: 'available',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${vehicle.vehicleNumber} marked as available'), backgroundColor: AppColors.successGreen),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Vehicle'),
        content: Text('Are you sure you want to remove ${vehicle.vehicleNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(vehicleStateProvider.notifier).deleteVehicle(vehicle.id);
        messenger.showSnackBar(
          SnackBar(content: Text('${vehicle.vehicleNumber} removed'), backgroundColor: AppColors.successGreen),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}

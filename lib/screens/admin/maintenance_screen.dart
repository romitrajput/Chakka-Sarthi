import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/app_button.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/app_text_field.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/searchable_dropdown.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';
import 'package:sanjay_roadlines_fleet/models/vehicle_model.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Widget build(BuildContext context) {
    final vehicleState = ref.watch(vehicleStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.maintenance),
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: vehicleState.when(
              data: (vehicles) {
                final maintenanceVehicles = vehicles.where((v) {
                  if (v.status != 'maintenance') return false;
                  if (_fromDate != null && (v.maintenanceFrom == null || v.maintenanceFrom!.isBefore(_fromDate!))) return false;
                  if (_toDate != null && (v.maintenanceFrom == null || v.maintenanceFrom!.isAfter(_toDate!))) return false;
                  return true;
                }).toList();

                if (maintenanceVehicles.isEmpty) {
                  return const Center(child: Text('No vehicles in maintenance'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: maintenanceVehicles.length,
                  itemBuilder: (context, index) {
                    return _buildMaintenanceCard(maintenanceVehicles[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMaintenanceSheet(),
        label: const Text(AppStrings.addMaintenance, style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: AppColors.accentOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Widget _buildMaintenanceCard(VehicleModel vehicle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  vehicle.vehicleNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const StatusChip(status: 'maintenance'),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.info_outline, 'Reason', vehicle.maintenanceReason ?? 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'From', vehicle.maintenanceFrom != null ? DateFormat('dd MMM yyyy').format(vehicle.maintenanceFrom!) : 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.event_repeat, 'Expected Return', vehicle.maintenanceExpectedReturn != null ? DateFormat('dd MMM yyyy').format(vehicle.maintenanceExpectedReturn!) : 'N/A'),
            const SizedBox(height: 16),
            AppButton(
              text: AppStrings.markAvailable,
              isOutlined: true,
              height: 40,
              textColor: AppColors.successGreen,
              backgroundColor: AppColors.successGreen,
              onPressed: () => _markAvailable(vehicle),
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

  void _markAvailable(VehicleModel vehicle) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(vehicleStateProvider.notifier).updateStatus(
            vehicleId: vehicle.id,
            status: 'available',
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Vehicle marked as available'), backgroundColor: AppColors.successGreen),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  void _showAddMaintenanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const AddMaintenanceSheet(),
    );
  }
}

class AddMaintenanceSheet extends ConsumerStatefulWidget {
  const AddMaintenanceSheet({super.key});

  @override
  ConsumerState<AddMaintenanceSheet> createState() => _AddMaintenanceSheetState();
}

class _AddMaintenanceSheetState extends ConsumerState<AddMaintenanceSheet> {
  final _reasonController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  VehicleModel? _selectedVehicle;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_selectedVehicle == null || _reasonController.text.isEmpty || _fromDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(vehicleStateProvider.notifier).updateStatus(
            vehicleId: _selectedVehicle!.id,
            status: 'maintenance',
            reason: _reasonController.text.trim(),
            from: _fromDate,
            to: _toDate,
          );
      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Vehicle added to maintenance'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableVehicles = ref.watch(availableVehiclesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Add to Maintenance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            availableVehicles.when(
              data: (vehicles) => SearchableDropdown<VehicleModel>(
                label: 'Vehicle',
                items: vehicles,
                itemAsString: (v) => v.vehicleNumber,
                selectedItem: _selectedVehicle,
                onChanged: (v) => setState(() => _selectedVehicle = v),
                compareFn: (a, b) => a.id == b.id,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            AppTextField(controller: _reasonController, label: 'Reason', hint: 'Enter maintenance reason'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _fromController,
                    label: 'From',
                    hint: 'Select Date',
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _fromDate = date;
                          _fromController.text = DateFormat('dd MMM yyyy').format(date);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppTextField(
                    controller: _toController,
                    label: 'Expected Return',
                    hint: 'Select Date',
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fromDate ?? DateTime.now(),
                        firstDate: _fromDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _toDate = date;
                          _toController.text = DateFormat('dd MMM yyyy').format(date);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            AppButton(text: 'SAVE MAINTENANCE', isLoading: _isSaving, onPressed: _save),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

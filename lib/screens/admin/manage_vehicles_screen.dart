import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/app_button.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/app_text_field.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/status_chip.dart';
import 'package:sanjay_roadlines_fleet/models/vehicle_model.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

class ManageVehiclesScreen extends ConsumerStatefulWidget {
  const ManageVehiclesScreen({super.key});

  @override
  ConsumerState<ManageVehiclesScreen> createState() => _ManageVehiclesScreenState();
}

class _ManageVehiclesScreenState extends ConsumerState<ManageVehiclesScreen> {
  // Multi-select delete mode (same behaviour as Manage Drivers)
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleState = ref.watch(vehicleStateProvider);
    final vehicles = vehicleState.value ?? const <VehicleModel>[];
    // Vehicles on a trip can't be deleted
    final deletable = vehicles.where((v) => v.status != 'in_transit').toList();
    final allSelected = deletable.isNotEmpty && _selectedIds.length == deletable.length;

    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectMode) _exitSelectMode();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selectMode
              ? IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: _exitSelectMode)
              : null,
          title: Text(_selectMode ? '${_selectedIds.length} selected' : 'Manage Vehicles'),
          actions: _selectMode
              ? [
                  IconButton(
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    tooltip: allSelected ? 'Clear selection' : 'Select all',
                    onPressed: () => setState(() {
                      if (allSelected) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds
                          ..clear()
                          ..addAll(deletable.map((v) => v.id));
                      }
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever),
                    tooltip: 'Delete selected',
                    onPressed: _selectedIds.isEmpty ? null : () => _confirmDeleteSelected(vehicles),
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add vehicles',
                    onPressed: _showAddOptions,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete vehicles',
                    onPressed: vehicles.isEmpty ? null : () => setState(() => _selectMode = true),
                  ),
                ],
        ),
        body: vehicleState.when(
          data: (vehicles) {
            if (vehicles.isEmpty) {
              return const Center(child: Text('No vehicles found. Tap + to add one.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                final onTrip = vehicle.status == 'in_transit';
                final selected = _selectedIds.contains(vehicle.id);
                return Card(
                  color: selected ? AppColors.primaryDark.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    leading: _selectMode
                        ? Checkbox(
                            value: selected,
                            onChanged: onTrip ? null : (_) => _toggleSelected(vehicle.id),
                          )
                        : null,
                    onTap: _selectMode
                        ? (onTrip ? null : () => _toggleSelected(vehicle.id))
                        : () => _showVehicleDetails(vehicle),
                    onLongPress: _selectMode || onTrip
                        ? null
                        : () => setState(() {
                              _selectMode = true;
                              _selectedIds.add(vehicle.id);
                            }),
                    title: Text(
                      vehicle.vehicleNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _selectMode && onTrip
                          ? 'On a trip — can\'t be deleted'
                          : 'Status: ${vehicle.status.replaceAll('_', ' ').toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: vehicle.status == 'available'
                            ? AppColors.successGreen
                            : vehicle.status == 'maintenance'
                                ? AppColors.errorRed
                                : AppColors.primaryDark,
                      ),
                    ),
                    trailing: _selectMode ? null : const Icon(Icons.chevron_right),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  /// "+" menu: add one vehicle, or import many from a file.
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.add_box_outlined, color: AppColors.primaryDark),
                title: const Text('Add Vehicle'),
                subtitle: const Text('Enter one vehicle\'s details'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddVehicleSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: AppColors.primaryDark),
                title: const Text('Import Vehicles (bulk upload)'),
                subtitle: const Text('Upload a CSV file with many vehicles'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showImportDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVehicleDetails(VehicleModel vehicle) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Text(vehicle.vehicleNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StatusChip(status: vehicle.status),
              const SizedBox(height: 16),
              const Text(
                'To delete vehicles, tap the bin icon at the top of the list.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSelected(List<VehicleModel> vehicles) async {
    final toDelete = vehicles.where((v) => _selectedIds.contains(v.id)).toList();
    if (toDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
            SizedBox(width: 8),
            Expanded(child: Text('Permanently delete vehicle details?')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(toDelete.length == 1
                  ? 'This vehicle will be permanently deleted:'
                  : 'These ${toDelete.length} vehicles will be permanently deleted:'),
              const SizedBox(height: 12),
              ...toDelete.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${v.vehicleNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  )),
              const SizedBox(height: 12),
              const Text('This cannot be undone.', style: TextStyle(color: AppColors.errorRed)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await Supabase.instance.client
          .from(SupabaseConstants.tableVehicles)
          .delete()
          .inFilter('id', toDelete.map((v) => v.id).toList())
          .neq('status', 'in_transit');
      ref.invalidate(vehicleStateProvider);
      navigator.pop(); // dismiss loading
      _exitSelectMode();
      messenger.showSnackBar(
        SnackBar(
          content: Text(toDelete.length == 1
              ? '${toDelete.first.vehicleNumber} has been deleted'
              : '${toDelete.length} vehicles deleted'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      navigator.pop(); // dismiss loading
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  void _showAddVehicleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddVehicleSheet(),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Vehicles'),
        content: const Text(
          'Choose a CSV file with one vehicle number per line.\n\n'
          'Example:\nvehicle_number\nMH01AB1234\nMH02CD5678\n\n'
          'Tip: in Excel or Google Sheets, use "Save as / Download → CSV".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _importVehicles();
            },
            child: const Text('CHOOSE FILE'),
          ),
        ],
      ),
    );
  }

  Future<void> _importVehicles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true, // needed on Android, otherwise the file contents are empty
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }

      // Parse CSV (strip an Excel "BOM" marker if present)
      final csvString = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
      final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvString.replaceAll('\r\n', '\n'));

      final vehicleNumbers = <String>{};
      for (final row in rows) {
        if (row.isEmpty) continue;
        final value = row[0].toString().trim().toUpperCase().replaceAll(' ', '');
        if (value.isEmpty || value == 'VEHICLE_NUMBER' || value == 'VEHICLENUMBER') continue;
        vehicleNumbers.add(value);
      }

      if (vehicleNumbers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No vehicle numbers found in file'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm Import'),
          content: Text('Found ${vehicleNumbers.length} vehicles. Import now?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('IMPORT')),
          ],
        ),
      );

      if (confirmed == true) {
        final count = await ref.read(vehicleStateProvider.notifier).bulkInsertVehicles(vehicleNumbers.toList());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $count vehicles successfully'), backgroundColor: AppColors.successGreen),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}

class AddVehicleSheet extends ConsumerStatefulWidget {
  const AddVehicleSheet({super.key});

  @override
  ConsumerState<AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends ConsumerState<AddVehicleSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() async {
    final vehicleNumber = _controller.text.trim();
    if (vehicleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter vehicle number'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(vehicleStateProvider.notifier).addVehicle(vehicleNumber);
      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Vehicle added successfully'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Add New Vehicle',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _controller,
            label: 'Vehicle Number',
            hint: 'e.g. MH01AB1234',
          ),
          const SizedBox(height: 32),
          AppButton(
            text: 'SAVE VEHICLE',
            isLoading: _isLoading,
            onPressed: _save,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

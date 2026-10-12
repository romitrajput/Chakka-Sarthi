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
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

class ManageVehiclesScreen extends ConsumerWidget {
  const ManageVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleState = ref.watch(vehicleStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vehicles'),
      ),
      body: vehicleState.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(child: Text('No vehicles found'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return Card(
                child: ListTile(
                  onTap: () => _showVehicleDetails(context, ref, vehicle),
                  title: Text(
                    vehicle.vehicleNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Status: ${vehicle.status.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: vehicle.status == 'available'
                          ? AppColors.successGreen
                          : vehicle.status == 'maintenance'
                              ? AppColors.errorRed
                              : AppColors.primaryDark,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Remove All button
          FloatingActionButton.extended(
            onPressed: () => _showRemoveAllDialog(context, ref),
            label: const Text('Remove All', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            backgroundColor: AppColors.errorRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          const SizedBox(height: 12),
          // Import button
          FloatingActionButton.extended(
            onPressed: () => _showImportDialog(context, ref),
            label: Text(
              ref.watch(languageProvider).languageCode == 'hi' ? 'वाहन आयात करें' : 'Import Vehicles',
              style: const TextStyle(color: Colors.white),
            ),
            icon: const Icon(Icons.file_upload, color: Colors.white),
            backgroundColor: AppColors.primaryMid,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          const SizedBox(height: 12),
          // Add vehicle button
          FloatingActionButton.extended(
            onPressed: () => _showAddVehicleSheet(context, ref),
            label: Text(
              ref.watch(languageProvider).languageCode == 'hi' ? 'वाहन जोड़ें' : 'Add Vehicle',
              style: const TextStyle(color: Colors.white),
            ),
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
            backgroundColor: AppColors.accentOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ],
      ),
    );
  }

  void _showVehicleDetails(BuildContext context, WidgetRef ref, VehicleModel vehicle) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
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
            Text(
              vehicle.vehicleNumber,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StatusChip(status: vehicle.status),
            const SizedBox(height: 24),
            AppButton(
              text: 'REMOVE VEHICLE',
              backgroundColor: AppColors.errorRed,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Remove Vehicle'),
                    content: Text(
                      'Are you sure you want to permanently remove ${vehicle.vehicleNumber}? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Remove', style: TextStyle(color: AppColors.errorRed)),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;

                if (!context.mounted) return;
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                try {
                  await ref.read(vehicleStateProvider.notifier).deleteVehicle(vehicle.id);
                  if (context.mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('${vehicle.vehicleNumber} has been removed'),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to remove vehicle: $e'),
                        backgroundColor: AppColors.errorRed,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRemoveAllDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    // Count vehicles first
    final vehicleState = ref.read(vehicleStateProvider);
    final count = vehicleState.maybeWhen(data: (v) => v.length, orElse: () => 0);

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicles to remove'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
            SizedBox(width: 8),
            Text('Remove All Vehicles'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove all $count vehicles?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Remove All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await Supabase.instance.client
          .from(SupabaseConstants.tableVehicles)
          .delete()
          .eq('company_code', user.companyCode);

      ref.invalidate(vehicleStateProvider);

      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All $count vehicles removed'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  void _showAddVehicleSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddVehicleSheet(),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Vehicles'),
        content: const Text('Select a CSV or Excel file with vehicle numbers.\n\nExpected format:\nvehicle_number\nMH01AB1234\nMH02CD5678'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _importVehicles(context, ref);
            },
            child: const Text('SELECT FILE'),
          ),
        ],
      ),
    );
  }

  Future<void> _importVehicles(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }
      
      // Parse CSV
      final csvString = String.fromCharCodes(bytes);
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      
      List<String> vehicleNumbers = [];
      for (var row in rows) {
        if (row.isNotEmpty) {
          final value = row[0].toString().trim();
          if (value.isNotEmpty && value != 'vehicle_number' && value != 'Vehicle Number') {
            vehicleNumbers.add(value);
          }
        }
      }

      if (vehicleNumbers.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No vehicle numbers found in file'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }

      // Show confirmation
      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Import'),
            content: Text('Found ${vehicleNumbers.length} vehicles. Import now?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('IMPORT')),
            ],
          ),
        );

        if (confirmed == true) {
          final count = await ref.read(vehicleStateProvider.notifier).bulkInsertVehicles(vehicleNumbers);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imported $count vehicles successfully'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/app_button.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/searchable_dropdown.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/models/vehicle_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/notification_provider.dart';
import 'package:sanjay_roadlines_fleet/core/utils/ticket_id_generator.dart';
import 'package:sanjay_roadlines_fleet/core/utils/local_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

final driversProvider = FutureProvider<List<UserModel>>((ref) async {
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

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  VehicleModel? _selectedVehicle;
  UserModel? _selectedDriver;
  bool _isAssigning = false;

  void _handleAssignTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null || _selectedDriver == null) return;

    setState(() => _isAssigning = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      final user = ref.read(authStateProvider).value!;
      
      // Fetch company short name for Ticket ID format
      final companyRes = await Supabase.instance.client
          .from(SupabaseConstants.tableCompanies)
          .select('short_name')
          .eq('company_code', user.companyCode)
          .single();
      
      final shortName = companyRes['short_name'] as String;

      // 1. Generate Ticket ID
      final ticketId = await TicketIdGenerator.generate(shortName);

      // 2. Create Ticket
      await ref.read(ticketStateProvider.notifier).createTicket(
            ticketId: ticketId,
            vehicleId: _selectedVehicle!.id,
            driverUserId: _selectedDriver!.userId,
          );

      // 3. Notify Driver
      await ref.read(notificationControllerProvider.notifier).send(
            targetUserId: _selectedDriver!.userId,
            title: 'New Trip Assigned',
            message: 'Trip $ticketId assigned. Vehicle: ${_selectedVehicle!.vehicleNumber}',
            ticketId: ticketId,
          );

      // 4. Local push notification to driver
      LocalNotificationService.showNotification(
        title: '🚛 New Trip Assigned',
        body: 'Trip $ticketId assigned. Vehicle: ${_selectedVehicle!.vehicleNumber}',
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ticket Assigned Successfully'), backgroundColor: AppColors.successGreen),
        );
        router.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableVehiclesAsync = ref.watch(availableVehiclesProvider);
    final driversAsync = ref.watch(driversProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.createNewTrip)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Vehicle & Driver', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              const SizedBox(height: 32),
              
              availableVehiclesAsync.when(
                data: (vehicles) => SearchableDropdown<VehicleModel>(
                  label: AppStrings.selectVehicle,
                  hint: 'Search Vehicle Number',
                  items: vehicles,
                  selectedItem: _selectedVehicle,
                  itemAsString: (v) => v.vehicleNumber,
                  onChanged: (v) => setState(() => _selectedVehicle = v),
                  validator: (v) => v == null ? 'Please select a vehicle' : null,
                  compareFn: (a, b) => a.id == b.id,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading vehicles: $e', style: const TextStyle(color: AppColors.errorRed)),
              ),
              
              const SizedBox(height: 24),
              
              driversAsync.when(
                data: (drivers) => SearchableDropdown<UserModel>(
                  label: AppStrings.selectDriver,
                  hint: 'Search Driver Name',
                  items: drivers,
                  selectedItem: _selectedDriver,
                  itemAsString: (d) => '${d.fullName} (${d.userId})',
                  onChanged: (d) => setState(() => _selectedDriver = d),
                  validator: (d) => d == null ? 'Please select a driver' : null,
                  compareFn: (a, b) => a.userId == b.userId,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading drivers: $e', style: const TextStyle(color: AppColors.errorRed)),
              ),
              
              const Spacer(),
              AppButton(text: AppStrings.assignTicket, isLoading: _isAssigning, onPressed: _handleAssignTicket),
            ],
          ),
        ),
      ),
    );
  }
}

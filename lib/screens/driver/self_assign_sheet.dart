import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/core/utils/ticket_id_generator.dart';
import 'package:sanjay_roadlines_fleet/models/vehicle_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/notification_repository.dart';
import 'package:sanjay_roadlines_fleet/repositories/ticket_repository.dart';
import 'package:sanjay_roadlines_fleet/repositories/vehicle_repository.dart';

/// Driver assigns a trip to themselves: picks an available vehicle and the trip date
/// (today or later). After that it works exactly like a trip assigned by the admin.
class SelfAssignSheet extends ConsumerStatefulWidget {
  const SelfAssignSheet({super.key, this.hindi = false});
  final bool hindi;

  @override
  ConsumerState<SelfAssignSheet> createState() => _SelfAssignSheetState();
}

class _SelfAssignSheetState extends ConsumerState<SelfAssignSheet> {
  List<VehicleModel>? _vehicles;
  VehicleModel? _vehicle;
  DateTime? _date;
  bool _saving = false;
  String? _error;

  String _t(String en, String hi) => widget.hindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    try {
      final list = await VehicleRepository().getAvailableVehicles(user.companyCode);
      if (mounted) setState(() => _vehicles = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load vehicles: $e');
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today, // no back-dated self-assignment
      lastDate: today.add(const Duration(days: 365)),
      helpText: _t('Trip date', 'यात्रा की तिथि'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _assign() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    if (_vehicle == null || _date == null) {
      setState(() => _error = _t('Select a vehicle and the trip date', 'वाहन और तिथि चुनें'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final company = await Supabase.instance.client
          .from(SupabaseConstants.tableCompanies)
          .select('short_name')
          .eq('company_code', user.companyCode)
          .single();
      final tripId = await TicketIdGenerator.generate((company['short_name'] as String?) ?? '');

      // Keep today's time for a trip dated today; otherwise the chosen day
      final now = DateTime.now();
      final assignedAt = DateUtils.isSameDay(_date, now)
          ? now
          : DateTime(_date!.year, _date!.month, _date!.day, now.hour, now.minute);

      await TicketRepository().createTicket(
        ticketId: tripId,
        vehicleId: _vehicle!.id,
        driverUserId: user.userId, // the driver's own (unchanging) login ID
        companyCode: user.companyCode,
        createdBy: '${user.fullName} (self-assigned)',
        createdByUserId: user.userId,
        assignedAt: assignedAt,
      );

      // Tell every admin
      try {
        final notifRepo = NotificationRepository();
        for (final adminId in await notifRepo.getAdminUserIds(user.companyCode)) {
          await notifRepo.sendNotification(
            targetUserId: adminId,
            title: 'Trip Self-Assigned',
            message: '${_vehicle!.vehicleNumber} · ${user.fullName} · Trip $tripId',
            ticketId: tripId,
          );
        }
      } catch (_) {}

      ref.invalidate(ticketStateProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(_t('Trip $tripId assigned to you', 'यात्रा $tripId आपको सौंपी गई')),
        backgroundColor: AppColors.successGreen,
      ));
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
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
          const SizedBox(height: 16),
          Text(_t('Self-assign a trip', 'स्वयं यात्रा लें'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_vehicles == null && _error == null)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_vehicles != null)
            DropdownButtonFormField<VehicleModel>(
              isExpanded: true,
              initialValue: _vehicle,
              decoration: InputDecoration(
                labelText: _t('Vehicle', 'वाहन'),
                border: const OutlineInputBorder(),
                helperText: _vehicles!.isEmpty ? _t('No vehicle is available right now', 'अभी कोई वाहन उपलब्ध नहीं है') : null,
              ),
              items: _vehicles!
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.vehicleNumber)))
                  .toList(),
              onChanged: (v) => setState(() => _vehicle = v),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(_date == null
                ? _t('Select trip date', 'यात्रा की तिथि चुनें')
                : DateFormat('dd MMM yyyy').format(_date!)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              alignment: Alignment.centerLeft,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _assign,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandYellow,
                foregroundColor: AppColors.onBrandYellow,
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onBrandYellow))
                  : Text(_t('ASSIGN TRIP TO ME', 'यात्रा मुझे सौंपें'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

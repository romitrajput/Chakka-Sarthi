import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/models/loading_status_model.dart';
import 'package:sanjay_roadlines_fleet/models/ticket_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';
import 'package:sanjay_roadlines_fleet/core/utils/local_notification_service.dart';
import 'package:sanjay_roadlines_fleet/repositories/notification_repository.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

class LoadingFormScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const LoadingFormScreen({super.key, required this.ticketId});

  @override
  ConsumerState<LoadingFormScreen> createState() => _LoadingFormScreenState();
}

class _LoadingFormScreenState extends ConsumerState<LoadingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lrController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _consigneeController = TextEditingController();
  final _productController = TextEditingController();
  final _weightController = TextEditingController();

  String _vehicleNumber = 'Loading...';
  bool _isFetching = true;
  DateTime? _assignedAt; // the trip's assigned date: loading can't be before it
  DateTime? _loadingDate; // chosen by the driver
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchVehicleNumber();
  }

  Future<void> _fetchVehicleNumber() async {
    try {
      final ticketRepo = ref.read(ticketRepositoryProvider);
      final ticket = await ticketRepo.getTicketById(widget.ticketId);
      final vehicleNum = await ticketRepo.getVehicleNumber(ticket.vehicleId);
      if (mounted) {
        setState(() {
          _vehicleNumber = vehicleNum;
          _assignedAt = ticket.assignedAt;
          _isFetching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {_vehicleNumber = 'Unknown'; _isFetching = false;});
    }
  }

  @override
  void dispose() {
    _lrController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _consigneeController.dispose();
    _productController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isFetching) return;
    if (_loadingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select the loading date'),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Check if this driver still owns this ticket (after potential reassignment)
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final currentTicket = await ref.read(ticketRepositoryProvider).getTicketById(widget.ticketId);
    if (currentTicket.driverUserId != user.userId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This trip has been reassigned to another driver. You can no longer submit details.'),
            backgroundColor: AppColors.warningYellow,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(false);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now().toUtc();

      final model = LoadingStatusModel(
        ticketId: widget.ticketId,
        vehicleNumber: _vehicleNumber,
        driverName: user.fullName,
        lrNumber: _lrController.text.trim(),
        journeyFrom: _fromController.text.trim(),
        journeyTo: _toController.text.trim(),
        consigneeName: _consigneeController.text.trim(),
        product: _productController.text.trim(),
        loadingWeightKgs: double.parse(_weightController.text.trim()),
        creationDate: _loadingDate!.toUtc(), // date chosen by the driver
        submittedAt: now,
      );

      await LoadingUnloadingRepository().submitLoadingStatus(model);

      // Show pop-up notification
      LocalNotificationService.notifyLoadingCompleted(user.fullName, widget.ticketId);

      // Notify ALL admins (supports multiple admin accounts)
      final notifRepo = NotificationRepository();
      final adminIds = await notifRepo.getAdminUserIds(user.companyCode);
      for (final adminId in adminIds) {
        await notifRepo.sendNotification(
          targetUserId: adminId,
          title: 'Trip Started',
          message: '$_vehicleNumber · ${user.fullName} · Trip ${widget.ticketId}',
          ticketId: widget.ticketId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Loading details submitted successfully'),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(currentLocale.languageCode == 'hi' ? 'लोडिंग विवरण' : 'Loading Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auto-filled card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _readOnlyRow(Icons.directions_car, currentLocale.languageCode == 'hi' ? 'वाहन नंबर' : 'Vehicle Number', _vehicleNumber),
                    const Divider(height: 20),
                    _readOnlyRow(Icons.person, currentLocale.languageCode == 'hi' ? 'चालक का नाम' : 'Driver Name', user?.fullName ?? ''),
                    const Divider(height: 20),
                    InkWell(
                      onTap: _pickLoadingDate,
                      child: Row(
                        children: [
                          Expanded(
                            child: _readOnlyRow(
                              Icons.calendar_today,
                              currentLocale.languageCode == 'hi' ? 'लोडिंग तिथि' : 'Loading Date (tap to select)',
                              _loadingDate == null
                                  ? (currentLocale.languageCode == 'hi' ? 'तिथि चुनें' : 'Select date')
                                  : DateFormat('dd MMM yyyy').format(_loadingDate!),
                            ),
                          ),
                          const Icon(Icons.edit_calendar_outlined, color: AppColors.primaryDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(currentLocale.languageCode == 'hi' ? 'यात्रा विवरण' : 'Trip Details',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
              const SizedBox(height: 12),
              _field(
                currentLocale.languageCode == 'hi' ? 'एलआर नंबर' : 'LR Number',
                _lrController,
                Icons.numbers,
                digitsOnly: true,
                maxLength: 5,
              ),
              _field(currentLocale.languageCode == 'hi' ? 'यात्रा कहां से' : 'Journey From', _fromController, Icons.location_on_outlined),
              _field(currentLocale.languageCode == 'hi' ? 'यात्रा कहां तक' : 'Journey To', _toController, Icons.flag_outlined),
              _field(currentLocale.languageCode == 'hi' ? 'प्राप्तकर्ता का नाम' : 'Consignee Name', _consigneeController, Icons.business_outlined),
              _field(currentLocale.languageCode == 'hi' ? 'उत्पाद' : 'Product', _productController, Icons.inventory_2_outlined),
              _field(currentLocale.languageCode == 'hi' ? 'लोडिंग वजन (किग्रा)' : 'Loading Weight (Kgs)', _weightController, Icons.scale_outlined,
                  isNumber: true),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandYellow,
                foregroundColor: AppColors.onBrandYellow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: AppColors.onBrandYellow, strokeWidth: 2))
                      : Text(currentLocale.languageCode == 'hi' ? 'लोडिंग स्थिति सबमिट करें' : 'SUBMIT LOADING STATUS',
                          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryMid, size: 20),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ]),
      ],
    );
  }

  /// Loading date: from the trip's assigned date up to today.
  Future<void> _pickLoadingDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final assigned = _assignedAt == null
        ? today.subtract(const Duration(days: 30))
        : DateUtils.dateOnly(_assignedAt!.toLocal());
    final last = assigned.isAfter(today) ? assigned : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _loadingDate ?? (today.isBefore(assigned) ? assigned : today),
      firstDate: assigned,
      lastDate: last,
      helpText: 'Loading date',
    );
    if (picked != null) setState(() => _loadingDate = picked);
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {bool isNumber = false, bool digitsOnly = false, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : digitsOnly
                ? TextInputType.number
                : TextInputType.text,
        maxLength: maxLength,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.errorRed)),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return '$label is required';
          if (isNumber) {
            if (double.tryParse(v) == null) return 'Weight must be a numeric value';
          }
          if (digitsOnly && maxLength != null) {
            if (v.length > maxLength) return '$label must be at most $maxLength digits';
          }
          return null;
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'dart:typed_data';
import 'package:sanjay_roadlines_fleet/core/utils/pdf_generator.dart';
import 'package:sanjay_roadlines_fleet/core/utils/shortage_calculator.dart';
import 'package:sanjay_roadlines_fleet/models/unloading_status_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';
import 'package:sanjay_roadlines_fleet/core/utils/local_notification_service.dart';
import 'package:sanjay_roadlines_fleet/repositories/notification_repository.dart';
import 'package:sanjay_roadlines_fleet/app.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/report_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:image_picker/image_picker.dart';

class UnloadingFormScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const UnloadingFormScreen({super.key, required this.ticketId});

  @override
  ConsumerState<UnloadingFormScreen> createState() =>
      _UnloadingFormScreenState();
}

class _UnloadingFormScreenState extends ConsumerState<UnloadingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _reportingDateController = TextEditingController();
  final _unloadingDateController = TextEditingController();

  double _loadingWeight = 0.0;
  double _shortage = 0.0;
  bool _isFetching = true;
  bool _isSubmitting = false;
  String _loadingWeightDisplay = '...';
  DateTime? _selectedReportingDate;
  DateTime? _loadingDate; // reporting date can't be before this
  final _consignerController = TextEditingController();
  DateTime? _selectedUnloadingDate;
  final List<Uint8List> _challanImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchLoadingWeight();
    _weightController.addListener(_recalcShortage);
    _unloadingDateController.text = '';
  }

  Future<void> _fetchLoadingWeight() async {
    try {
      final repo = LoadingUnloadingRepository();
      final loading = await repo.getLoadingStatus(widget.ticketId);
      if (loading != null && mounted) {
        setState(() {
          _loadingDate = loading.creationDate;
          _loadingWeight = loading.loadingWeightKgs;
          _loadingWeightDisplay =
              '${loading.loadingWeightKgs.toStringAsFixed(2)} Kgs';
          _isFetching = false;
        });
      } else if (mounted) {
        setState(() {
          _isFetching = false;
          _loadingWeightDisplay = 'N/A';
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isFetching = false;
          _loadingWeightDisplay = 'Error';
        });
    }
  }

  void _recalcShortage() {
    final val = double.tryParse(_weightController.text) ?? 0.0;
    setState(() {
      _shortage = ShortageCalculator.calculate(_loadingWeight, val);
    });
  }

  Future<void> _pickChallanImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _challanImages.add(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  Future<void> _pickChallanFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _challanImages.add(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  /// Reporting date: on or after the loading date (earlier dates are disabled).
  Future<void> _pickReportingDate() async {
    final first = _loadingDate == null
        ? DateUtils.dateOnly(DateTime.now())
        : DateUtils.dateOnly(_loadingDate!.toUtc().add(const Duration(hours: 5, minutes: 30)));
    final last = first.add(const Duration(days: 365));
    final today = DateUtils.dateOnly(DateTime.now());
    var initial = _selectedReportingDate ?? today;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Reporting date',
    );
    if (picked != null) {
      setState(() {
        _selectedReportingDate = picked;
        _reportingDateController.text = DateFormat('dd MMM yyyy').format(picked);
        // Unloading can't be before reporting: clear it if it now is
        if (_selectedUnloadingDate != null && _selectedUnloadingDate!.isBefore(picked)) {
          _selectedUnloadingDate = null;
          _unloadingDateController.text = '';
        }
      });
    }
  }

  /// Unloading date: on or after the reporting date (earlier dates are disabled).
  Future<void> _showDatePicker(
    BuildContext context,
    TextEditingController controller,
    String dateType,
  ) async {
    if (_selectedReportingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select the reporting date first'),
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }
    final first = DateUtils.dateOnly(_selectedReportingDate!);
    final last = first.add(const Duration(days: 365));
    final today = DateUtils.dateOnly(DateTime.now());
    var initial = _selectedUnloadingDate ?? today;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Unloading date',
    );
    if (picked != null) {
      setState(() {
        if (dateType == 'unloadingDate') {
          _selectedUnloadingDate = picked;
          controller.text = DateFormat('dd MMM yyyy').format(picked);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate reporting date
    if (_selectedReportingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reporting date is required'),
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }

    // Validate unloading date
    if (_selectedUnloadingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unloading date is required'),
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    // Check if this driver still owns this ticket (after potential reassignment)
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final ticketRepo = ref.read(ticketRepositoryProvider);
    final ticket = await ticketRepo.getTicketById(widget.ticketId);
    
    // Verify driver still owns this ticket
    if (ticket.driverUserId != user.userId) {
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

    final loadingRepo = LoadingUnloadingRepository();
    final loading = await loadingRepo.getLoadingStatus(widget.ticketId);

    if (loading == null) throw Exception('Loading status not found');

    try {
      final now = DateTime.now().toUtc();
      final unloadingWeight = double.parse(_weightController.text.trim());

      final unloadingStatus = UnloadingStatusModel(
        ticketId: widget.ticketId,
        unloadingWeightKgs: unloadingWeight,
        unloadingDate: _selectedUnloadingDate!.toUtc(),
        shortageKgs: _shortage,
        submittedAt: now,
      );

      // Upload challan images
      List<String> uploadedUrls = [];
      for (int i = 0; i < _challanImages.length; i++) {
        final url = await loadingRepo.uploadChallanDocument(
          ticketId: widget.ticketId,
          companyCode: user.companyCode,
          imageBytes: _challanImages[i],
          fileName: 'challan_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        uploadedUrls.add(url);
      }

      // Update ticket with challan URLs
      await ticketRepo.updateChallanUrls(
        ticketId: widget.ticketId,
        challanUrls: uploadedUrls,
      );

      // Update reporting date
      await ticketRepo.updateReportingDate(
        ticketId: widget.ticketId,
        reportingDate: _selectedReportingDate!,
        unloadingDate: _selectedUnloadingDate,
      );

      // Pop-up: Reporting Date Submitted
      LocalNotificationService.notifyReportingDateSubmitted(user.fullName, widget.ticketId);

      // Generate PDF
      late final pdfBytes;
      try {
        pdfBytes = await PdfGenerator.generateTripPdf(
          ticket: ticket.copyWith(
            reportingDate: _selectedReportingDate,
            challanUrls: uploadedUrls,
          ),
          loading: loading,
          unloading: unloadingStatus,
          companyName: await currentBusinessName(ref),
          unloadedBy: user.fullName,
          consignerName: _consignerController.text.trim(),
          driverChanges: await ReportRepository().driverChangeLines(widget.ticketId),
        );
      } catch (_) {
        pdfBytes = Uint8List(0);
      }

      await loadingRepo.submitUnloadingStatus(
        unloadingStatus: unloadingStatus,
        vehicleId: ticket.vehicleId,
        pdfBytes: pdfBytes,
        companyCode: user.companyCode,
      );

      // Record who did the unloading (matters when a trip was re-assigned mid-way)
      try {
        await Supabase.instance.client
            .from(SupabaseConstants.tableUnloadingStatus)
            .update({
              'unloaded_by': user.fullName,
              'consigner_name': _consignerController.text.trim(),
            })
            .eq('ticket_id', widget.ticketId);
      } catch (_) {}

      // Pop-up: Unloading Completed
      LocalNotificationService.notifyUnloadingCompleted(user.fullName, widget.ticketId);

      // Force fresh data from Supabase
      await ref.read(ticketStateProvider.notifier).refresh();
      ref.invalidate(completedTicketsProvider);

      if (!mounted) return;
      context.go('/driver/dashboard');

      // Notify ALL admins (supports multiple admin accounts)
      final notifRepo = NotificationRepository();
      final adminIds = await notifRepo.getAdminUserIds(user.companyCode);
      for (final adminId in adminIds) {
        await notifRepo.sendNotification(
          targetUserId: adminId,
          title: 'Trip Completed',
          message:
              '${loading.vehicleNumber} · ${user.fullName} · Trip ${widget.ticketId} · Shortage: ${_shortage.toStringAsFixed(2)} Kgs',
          ticketId: widget.ticketId,
        );
      }

      // Show pop-up notification
      LocalNotificationService.notifyTripCompleted(user.fullName, widget.ticketId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip completed successfully!'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/driver/dashboard');
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
  void dispose() {
    _weightController.removeListener(_recalcShortage);
    _weightController.dispose();
    _reportingDateController.dispose();
    _consignerController.dispose();
    _unloadingDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(currentLocale.languageCode == 'hi' ? 'अनलोडिंग विवरण' : 'Unloading Details')),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            Icons.scale_outlined,
                            currentLocale.languageCode == 'hi' ? 'लोडिंग वजन' : 'Loading Weight',
                            _loadingWeightDisplay,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      currentLocale.languageCode == 'hi' ? 'अनलोडिंग विवरण' : 'Unloading Details',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Unloading Weight input (numeric only)
                    TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      // Whole kilograms, up to 5 digits (shown with .00)
                      maxLength: 5,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        counterText: '',
                        suffixText: '.00 kg',
                        labelText: currentLocale.languageCode == 'hi' ? 'अनलोडिंग वजन (किग्रा)' : 'Unloading Weight (Kgs)',
                        prefixIcon: const Icon(
                          Icons.scale_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Unloading weight is required';
                        if (double.tryParse(v) == null)
                          return 'Weight must be a numeric value';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // CONSIGNER NAME (same style as Consignee Name in the loading form)
                    Text(
                      currentLocale.languageCode == 'hi' ? 'प्राप्तकर्ता का नाम' : 'Consignee Name',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _consignerController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: currentLocale.languageCode == 'hi' ? 'प्राप्तकर्ता का नाम लिखें' : 'Enter consignee name',
                        prefixIcon: const Icon(Icons.business_outlined, size: 20, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Consignee name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // REPORTING DATE
                    Text(
                      currentLocale.languageCode == 'hi' ? 'रिपोर्टिंग तिथि' : 'Reporting Date',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reportingDateController,
                      readOnly: true,
                      onTap: _pickReportingDate,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: currentLocale.languageCode == 'hi' ? 'तिथि चुनें' : 'Select Date',
                        prefixIcon: const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Reporting date is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // UNLOADING DATE (Manual Entry)
                    Text(
                      currentLocale.languageCode == 'hi' ? 'अनलोडिंग तिथि' : 'Unloading Date',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _unloadingDateController,
                      readOnly: true,
                      onTap: () => _showDatePicker(context, _unloadingDateController, 'unloadingDate'),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: currentLocale.languageCode == 'hi' ? 'तिथि चुनें' : 'Select Unloading Date',
                        prefixIcon: const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Unloading date is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Shortage display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.errorRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.errorRed,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentLocale.languageCode == 'hi' ? 'कमी (किग्रा)' : 'Shortage (Kgs)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.errorRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_shortage.toStringAsFixed(2)} Kgs',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.errorRed,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '${_loadingWeight.toStringAsFixed(2)} - ${(double.tryParse(_weightController.text) ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CHALLAN/DOCUMENT UPLOAD
                    Text(
                      currentLocale.languageCode == 'hi' ? 'चालान/दस्तावेज' : 'Challan/Document',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Upload buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickChallanImage,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: Text(currentLocale.languageCode == 'hi' ? 'कैमरा' : 'Camera'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.primaryDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickChallanFromGallery,
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: Text(currentLocale.languageCode == 'hi' ? 'गैलरी' : 'Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.primaryDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Show uploaded images
                    if (_challanImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _challanImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: MemoryImage(_challanImages[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _challanImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.errorRed,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                currentLocale.languageCode == 'hi' ? 'अनलोडिंग स्थिति सबमिट करें' : 'SUBMIT UNLOADING STATUS',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryMid, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

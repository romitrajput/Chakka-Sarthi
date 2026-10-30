import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_strings.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/app_button.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/app_text_field.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/auth_repository.dart';
import 'package:sanjay_roadlines_fleet/core/utils/user_id_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/create_ticket_screen.dart' show driversProvider;
import 'package:sanjay_roadlines_fleet/screens/admin/assigned_tickets_screen.dart' show reassignDriversProvider;
import 'package:sanjay_roadlines_fleet/providers/driver_names_provider.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/providers/licence_alerts_provider.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

final allDriversProvider = FutureProvider<List<UserModel>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .from(SupabaseConstants.tableUsers)
      .select('id, user_id, full_name, mobile, role, company_code, is_first_login, is_active, sequential_num, created_at, driving_license_url, aadhaar_card_url, license_expiry')
      .eq('company_code', user.companyCode)
      .eq('role', 'driver')
      .order('full_name');
  
  return (response as List).map((json) => UserModel.fromJson(json as Map<String, dynamic>)).toList();
});

class ManageDriversScreen extends ConsumerStatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  ConsumerState<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends ConsumerState<ManageDriversScreen> {
  // Multi-select delete mode
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(allDriversProvider);
    final drivers = driversAsync.value ?? const <UserModel>[];
    final allSelected = drivers.isNotEmpty && _selectedIds.length == drivers.length;

    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectMode) _exitSelectMode();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selectMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: _exitSelectMode,
                )
              : null,
          title: Text(_selectMode ? '${_selectedIds.length} selected' : 'Manage Drivers'),
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
                          ..addAll(drivers.map((d) => d.userId));
                      }
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever),
                    tooltip: 'Delete selected',
                    onPressed: _selectedIds.isEmpty ? null : () => _confirmDeleteSelected(drivers),
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add driver',
                    onPressed: _showAddDriverSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete drivers',
                    onPressed: drivers.isEmpty ? null : () => setState(() => _selectMode = true),
                  ),
                ],
        ),
        body: driversAsync.when(
          data: (drivers) {
            if (drivers.isEmpty) {
              return const Center(child: Text('No drivers found. Tap + to add one.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                final selected = _selectedIds.contains(driver.userId);
                return Card(
                  color: selected ? AppColors.primaryDark.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    leading: _selectMode
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) => _toggleSelected(driver.userId),
                          )
                        : null,
                    onTap: () => _selectMode ? _toggleSelected(driver.userId) : _showDriverDetails(driver),
                    onLongPress: _selectMode
                        ? null
                        : () => setState(() {
                              _selectMode = true;
                              _selectedIds.add(driver.userId);
                            }),
                    title: Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver.userId, style: const TextStyle(color: AppColors.primaryDark, fontSize: 12)),
                        Text(driver.mobile, style: const TextStyle(fontSize: 12)),
                        Row(
                          children: [
                            _docStatus(driver.drivingLicenseUrl != null, 'License uploaded', 'No license'),
                            const SizedBox(width: 8),
                            _docStatus(driver.aadhaarCardUrl != null, 'Aadhaar uploaded', 'No Aadhaar'),
                          ],
                        ),
                        if (driver.licenseNeedsAttention)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              licenceStatusText(driver),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.errorRed),
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: driver.isActive ? AppColors.availableBg : AppColors.cancelledBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        driver.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: driver.isActive ? AppColors.successGreen : AppColors.errorRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

  Widget _docStatus(bool ok, String yes, String no) {
    final color = ok ? AppColors.successGreen : AppColors.errorRed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, size: 12, color: color),
        const SizedBox(width: 4),
        Text(ok ? yes : no, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  void _toggleSelected(String userId) {
    setState(() {
      if (!_selectedIds.remove(userId)) _selectedIds.add(userId);
    });
  }

  /// Shows a driver document (licence / Aadhaar) full screen, with pinch-to-zoom.
  void _openDocument(String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    // cache-buster so a re-uploaded document is not shown stale
                    '$url${url.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}',
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : const CircularProgressIndicator(color: Colors.white),
                    errorBuilder: (c, e, s) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load this document. Check that the "driver-documents" storage bucket is public in Supabase.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deletes the driver's uploaded documents (best effort) and their user record.
  Future<void> _deleteDriverFiles(UserModel driver) async {
    final storage = Supabase.instance.client.storage;
    try {
      await storage.from(SupabaseConstants.bucketDriverDocuments).remove([
        '${driver.companyCode}/${driver.userId}/license.jpg',
        '${driver.companyCode}/${driver.userId}/aadhaar.jpg',
      ]);
    } catch (_) {
      // Continue even if storage delete fails
    }
  }

  Future<void> _confirmDeleteSelected(List<UserModel> drivers) async {
    final toDelete = drivers.where((d) => _selectedIds.contains(d.userId)).toList();
    if (toDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
            SizedBox(width: 8),
            Expanded(child: Text('Delete permanently?')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDelete.length == 1
                    ? 'This driver and their documents will be permanently deleted:'
                    : 'These ${toDelete.length} drivers and their documents will be permanently deleted:',
              ),
              const SizedBox(height: 12),
              ...toDelete.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${d.fullName} (${d.userId})', style: const TextStyle(fontWeight: FontWeight.w600)),
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
      for (final driver in toDelete) {
        await _deleteDriverFiles(driver);
      }
      await Supabase.instance.client
          .from(SupabaseConstants.tableUsers)
          .delete()
          .inFilter('user_id', toDelete.map((d) => d.userId).toList())
          .eq('role', 'driver');

      ref.invalidate(allDriversProvider);
      ref.invalidate(driverNamesProvider);
      ref.invalidate(expiringLicencesProvider);
      navigator.pop(); // dismiss loading
      _exitSelectMode();
      messenger.showSnackBar(
        SnackBar(
          content: Text(toDelete.length == 1
              ? '${toDelete.first.fullName} has been deleted'
              : '${toDelete.length} drivers deleted'),
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

  void _showDriverDetails(UserModel driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text(driver.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(driver.userId, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.event_outlined,
                      color: driver.licenseNeedsAttention ? AppColors.errorRed : AppColors.primaryDark),
                  title: const Text('Licence expiry'),
                  subtitle: Text(
                    licenceStatusText(driver),
                    style: TextStyle(color: driver.licenseNeedsAttention ? AppColors.errorRed : AppColors.textSecondary),
                  ),
                  trailing: TextButton(
                    onPressed: () => _pickLicenceExpiry(driver),
                    child: Text(driver.licenseExpiry == null ? 'Set' : 'Change'),
                  ),
                ),

                // Uploaded documents
                if (driver.drivingLicenseUrl != null || driver.aadhaarCardUrl != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Uploaded Documents:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (driver.drivingLicenseUrl != null)
                    ListTile(
                      leading: const Icon(Icons.description, color: AppColors.primaryDark),
                      title: const Text('Driving License'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openDocument('Driving License', driver.drivingLicenseUrl!),
                    ),
                  if (driver.aadhaarCardUrl != null)
                    ListTile(
                      leading: const Icon(Icons.credit_card, color: AppColors.primaryDark),
                      title: const Text('Aadhaar Card'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openDocument('Aadhaar Card', driver.aadhaarCardUrl!),
                    ),
                ],

                const SizedBox(height: 32),
                AppButton(
                  text: AppStrings.resetMpin,
                  isOutlined: true,
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(this.context);
                    final navigator = Navigator.of(this.context);
                    await AuthRepository().resetMpin(driver.userId);
                    if (mounted) {
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Driver MPIN reset. They must login with mobile number.'), backgroundColor: AppColors.successGreen),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: driver.isActive ? 'DEACTIVATE DRIVER' : 'ACTIVATE DRIVER',
                  backgroundColor: driver.isActive ? AppColors.errorRed : AppColors.successGreen,
                  onPressed: () async {
                    final navigator = Navigator.of(this.context);
                    await Supabase.instance.client
                        .from(SupabaseConstants.tableUsers)
                        .update({'is_active': !driver.isActive})
                        .eq('user_id', driver.userId);
                    // Refresh every driver list so the change shows everywhere at once
                    ref.invalidate(allDriversProvider);
      ref.invalidate(driverNamesProvider);
      ref.invalidate(expiringLicencesProvider);
                    ref.invalidate(driversProvider);
                    ref.invalidate(reassignDriversProvider);
                    if (mounted) navigator.pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickLicenceExpiry(UserModel driver) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: driver.licenseExpiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 25),
      helpText: 'Driving licence expiry',
    );
    if (picked == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await Supabase.instance.client
          .from(SupabaseConstants.tableUsers)
          .update({'license_expiry': DateFormat('yyyy-MM-dd').format(picked)})
          .eq('user_id', driver.userId);
      ref.invalidate(allDriversProvider);
      ref.invalidate(expiringLicencesProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Licence expiry saved for ${driver.fullName}'),
        backgroundColor: AppColors.successGreen,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e'), backgroundColor: AppColors.errorRed));
    }
  }

  void _showAddDriverSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const AddDriverSheet(),
    );
  }
}

class AddDriverSheet extends ConsumerStatefulWidget {
  const AddDriverSheet({super.key});

  @override
  ConsumerState<AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends ConsumerState<AddDriverSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _isLoading = false;
  DateTime? _licenseExpiry;
  final ImagePicker _picker = ImagePicker();
  
  Uint8List? _licenseImage;
  Uint8List? _aadhaarImage;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(String type) async {
    try {
      // Show source selection dialog
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type == 'license' ? 'Upload Driving License' : 'Upload Aadhaar Card',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primaryDark),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primaryDark),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (type == 'license') {
            _licenseImage = bytes;
          } else {
            _aadhaarImage = bytes;
          }
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

  // --- Validators ---

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Name is too short';
    }
    if (RegExp(r'[0-9]').hasMatch(trimmed)) {
      return 'Name cannot contain numbers';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return 'Enter both first name and last name';
    }
    for (final part in parts) {
      if (part.length < 2) {
        return 'Each name part must be at least 2 characters';
      }
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(trimmed)) {
      return 'Mobile number must be exactly 10 digits';
    }
    if (!RegExp(r'^[6-9]').hasMatch(trimmed)) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  // --- Save ---

  void _save() async {
    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate documents are required
    if (_licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driving License is required'), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    if (_aadhaarImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aadhaar Card is required'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final admin = ref.read(authStateProvider).value!;
      
      final existingMobile = await Supabase.instance.client
          .from(SupabaseConstants.tableUsers)
          .select('user_id')
          .eq('mobile', _mobileController.text.trim())
          .maybeSingle();

      if (existingMobile != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('This mobile number is already registered with another user'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      final company = await Supabase.instance.client
          .from(SupabaseConstants.tableCompanies)
          .select('state_code, short_name')
          .eq('company_code', admin.companyCode)
          .single();

      final userId = await UserIdGenerator.generate(
        stateCode: company['state_code'] as String,
        companyCode: admin.companyCode,
        role: 'driver',
        companyShortName: company['short_name'] as String,
        fullName: _nameController.text.trim(),
      );

      final seqRes = await Supabase.instance.client
          .from(SupabaseConstants.tableUsers)
          .select('sequential_num')
          .eq('company_code', admin.companyCode)
          .order('sequential_num', ascending: false)
          .limit(1)
          .maybeSingle();
      
      final nextSeq = (seqRes?['sequential_num'] as int? ?? 0) + 1;

      // Auto-generate 4-digit MPIN
      final random = Random();
      final autoMpin = '${1000 + random.nextInt(9000)}'; // e.g. 4821
      final hashedMpin = sha256.convert(utf8.encode(autoMpin)).toString();

      // Insert driver with auto-generated MPIN
      await Supabase.instance.client.from(SupabaseConstants.tableUsers).insert({
        'user_id': userId,
        'full_name': _nameController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'role': 'driver',
        'company_code': admin.companyCode,
        'mpin_hash': hashedMpin,
        'is_first_login': false,
        'is_active': true,
        'sequential_num': nextSeq,
        if (_licenseExpiry != null) 'license_expiry': DateFormat('yyyy-MM-dd').format(_licenseExpiry!),
      });

      // Upload documents
      if (_licenseImage != null) {
        final licensePath = '${admin.companyCode}/$userId/license.jpg';
        await Supabase.instance.client.storage
            .from(SupabaseConstants.bucketDriverDocuments)
            .uploadBinary(licensePath, _licenseImage!, 
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
        final licenseUrl = Supabase.instance.client.storage
            .from(SupabaseConstants.bucketDriverDocuments)
            .getPublicUrl(licensePath);
        await Supabase.instance.client
            .from(SupabaseConstants.tableUsers)
            .update({'driving_license_url': licenseUrl})
            .eq('user_id', userId);
      }

      if (_aadhaarImage != null) {
        final aadhaarPath = '${admin.companyCode}/$userId/aadhaar.jpg';
        await Supabase.instance.client.storage
            .from(SupabaseConstants.bucketDriverDocuments)
            .uploadBinary(aadhaarPath, _aadhaarImage!, 
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
        final aadhaarUrl = Supabase.instance.client.storage
            .from(SupabaseConstants.bucketDriverDocuments)
            .getPublicUrl(aadhaarPath);
        await Supabase.instance.client
            .from(SupabaseConstants.tableUsers)
            .update({'aadhaar_card_url': aadhaarUrl})
            .eq('user_id', userId);
      }

      if (mounted) {
        ref.invalidate(allDriversProvider);
      ref.invalidate(driverNamesProvider);
      ref.invalidate(expiringLicencesProvider);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Driver Added Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share these credentials with the driver:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                _credentialRow('User ID', userId),
                const SizedBox(height: 12),
                _credentialRow('MPIN', autoMpin),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF856404)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Driver can login with User ID + MPIN directly. No need to set MPIN again.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF856404)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final text = 'User ID: $userId\nMPIN: $autoMpin';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Credentials copied to clipboard'), backgroundColor: AppColors.successGreen),
                  );
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // close dialog first
                  navigator.pop(); // then close bottom sheet
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to add driver: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Add New Driver',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'e.g. Rajesh Kumar',
                maxLength: 50,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), FilteringTextInputFormatter.deny(RegExp(r'\d'))],
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _mobileController,
                label: 'Mobile Number',
                hint: 'e.g. 9876543210',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateMobile,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _licenseExpiry ?? now.add(const Duration(days: 365)),
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 25),
                    helpText: 'Driving licence expiry',
                  );
                  if (picked != null) setState(() => _licenseExpiry = picked);
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(_licenseExpiry == null
                    ? 'Licence expiry date (optional)'
                    : 'Licence expires ${DateFormat('dd MMM yyyy').format(_licenseExpiry!)}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerLeft,
                ),
              ),

              // Document uploads (Required)
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Documents', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Driving License
              OutlinedButton.icon(
                onPressed: () => _pickDocument('license'),
                icon: Icon(
                  _licenseImage != null ? Icons.check_circle : Icons.upload_file,
                  color: _licenseImage != null ? AppColors.successGreen : AppColors.primaryDark,
                ),
                label: Text(_licenseImage != null ? 'License Selected ✓' : 'Upload Driving License'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.primaryDark,
                  side: BorderSide(
                    color: _licenseImage != null ? AppColors.successGreen : AppColors.divider,
                  ),
                ),
              ),
              if (_licenseImage != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _licenseImage!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              
              // Aadhaar Card
              OutlinedButton.icon(
                onPressed: () => _pickDocument('aadhaar'),
                icon: Icon(
                  _aadhaarImage != null ? Icons.check_circle : Icons.upload_file,
                  color: _aadhaarImage != null ? AppColors.successGreen : AppColors.primaryDark,
                ),
                label: Text(_aadhaarImage != null ? 'Aadhaar Selected ✓' : 'Upload Aadhaar Card'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.primaryDark,
                  side: BorderSide(
                    color: _aadhaarImage != null ? AppColors.successGreen : AppColors.divider,
                  ),
                ),
              ),
              if (_aadhaarImage != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _aadhaarImage!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              AppButton(
                text: 'SAVE DRIVER',
                isLoading: _isLoading,
                onPressed: _save,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          SelectableText(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
        ],
      ),
    );
  }
}

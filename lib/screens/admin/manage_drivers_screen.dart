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
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

final allDriversProvider = FutureProvider<List<UserModel>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .from(SupabaseConstants.tableUsers)
      .select('id, user_id, full_name, mobile, role, company_code, mpin_hash, is_first_login, is_active, sequential_num, created_at, driving_license_url, aadhaar_card_url')
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
  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(allDriversProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Drivers'),
      ),
      body: driversAsync.when(
        data: (drivers) {
          if (drivers.isEmpty) {
            return const Center(child: Text('No drivers found'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return Card(
                child: ListTile(
                  onTap: () => _showDriverDetails(driver),
                  title: Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.userId, style: const TextStyle(color: AppColors.primaryDark, fontSize: 12)),
                      Text(driver.mobile, style: const TextStyle(fontSize: 12)),
                      // Show document status
                      Row(
                        children: [
                          Icon(
                            driver.drivingLicenseUrl != null ? Icons.check_circle : Icons.cancel,
                            size: 12,
                            color: driver.drivingLicenseUrl != null ? AppColors.successGreen : AppColors.errorRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            driver.drivingLicenseUrl != null ? 'License uploaded' : 'No license',
                            style: TextStyle(
                              fontSize: 10,
                              color: driver.drivingLicenseUrl != null ? AppColors.successGreen : AppColors.errorRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            driver.aadhaarCardUrl != null ? Icons.check_circle : Icons.cancel,
                            size: 12,
                            color: driver.aadhaarCardUrl != null ? AppColors.successGreen : AppColors.errorRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            driver.aadhaarCardUrl != null ? 'Aadhaar uploaded' : 'No Aadhaar',
                            style: TextStyle(
                              fontSize: 10,
                              color: driver.aadhaarCardUrl != null ? AppColors.successGreen : AppColors.errorRed,
                            ),
                          ),
                        ],
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Remove All button
          FloatingActionButton.extended(
            onPressed: () => _showRemoveAllDriversDialog(),
            label: const Text('Remove All', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            backgroundColor: AppColors.errorRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          const SizedBox(height: 12),
          // Add Driver button
          FloatingActionButton.extended(
            onPressed: () => _showAddDriverSheet(),
            label: const Text(AppStrings.addDriver, style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.person_add, color: Colors.white),
            backgroundColor: AppColors.accentOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ],
      ),
    );
  }

  void _showDriverDetails(UserModel driver) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(driver.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(driver.userId, style: const TextStyle(color: AppColors.textSecondary)),
              
              // Show uploaded documents
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
                    onTap: () {
                      // Open document URL
                    },
                  ),
                if (driver.aadhaarCardUrl != null)
                  ListTile(
                    leading: const Icon(Icons.credit_card, color: AppColors.primaryDark),
                    title: const Text('Aadhaar Card'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // Open document URL
                    },
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
                  ref.invalidate(allDriversProvider);
                  if (mounted) navigator.pop();
                },
              ),
              const SizedBox(height: 12),
              // Remove Driver
              AppButton(
                text: 'REMOVE DRIVER',
                backgroundColor: AppColors.errorRed,
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(this.context);
                  final navigator = Navigator.of(this.context);

                  final confirm = await showDialog<bool>(
                    context: this.context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove Driver'),
                      content: Text('Are you sure you want to permanently remove ${driver.fullName}? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove', style: TextStyle(color: AppColors.errorRed)),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !mounted) return;

                  try {
                    // Delete storage files if they exist
                    final storage = Supabase.instance.client.storage;
                    if (driver.drivingLicenseUrl != null) {
                      await storage.from(SupabaseConstants.bucketDriverDocuments).remove([
                        '${driver.companyCode}/${driver.userId}/license.jpg',
                      ]);
                    }
                    if (driver.aadhaarCardUrl != null) {
                      await storage.from(SupabaseConstants.bucketDriverDocuments).remove([
                        '${driver.companyCode}/${driver.userId}/aadhaar.jpg',
                      ]);
                    }
                    // Delete user record
                    await Supabase.instance.client
                        .from(SupabaseConstants.tableUsers)
                        .delete()
                        .eq('user_id', driver.userId);
                    ref.invalidate(allDriversProvider);
                    if (mounted) {
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('${driver.fullName} has been removed'), backgroundColor: AppColors.successGreen),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('Failed to remove driver: $e'), backgroundColor: AppColors.errorRed),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRemoveAllDriversDialog() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final driversAsync = ref.read(allDriversProvider);
    final count = driversAsync.maybeWhen(data: (d) => d.length, orElse: () => 0);

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No drivers to remove'), backgroundColor: AppColors.errorRed),
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
            Text('Remove All Drivers'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove all $count drivers?\n\nThis will also delete their documents. This action cannot be undone.',
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

    if (confirmed != true || !mounted) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Get all drivers to delete their storage files
      final drivers = driversAsync.value ?? [];
      final storage = Supabase.instance.client.storage;

      for (final driver in drivers) {
        try {
          if (driver.drivingLicenseUrl != null) {
            await storage.from(SupabaseConstants.bucketDriverDocuments).remove([
              '${driver.companyCode}/${driver.userId}/license.jpg',
            ]);
          }
          if (driver.aadhaarCardUrl != null) {
            await storage.from(SupabaseConstants.bucketDriverDocuments).remove([
              '${driver.companyCode}/${driver.userId}/aadhaar.jpg',
            ]);
          }
        } catch (_) {
          // Continue even if storage delete fails
        }
      }

      // Delete all driver records
      await Supabase.instance.client
          .from(SupabaseConstants.tableUsers)
          .delete()
          .eq('company_code', user.companyCode)
          .eq('role', 'driver');

      ref.invalidate(allDriversProvider);

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All $count drivers removed'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
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

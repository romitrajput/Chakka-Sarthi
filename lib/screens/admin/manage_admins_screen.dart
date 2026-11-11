import 'package:sanjay_roadlines_fleet/core/utils/usage_log.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

/// Admin login IDs: SRLTRANSPORTAD + first 2 letters of first name + @ + number.
/// Every admin ends in @1987, e.g. Ajay → SRLTRANSPORTADAJ@1987, Vinay → SRLTRANSPORTADVI@1987
const String kAdminIdPrefix = 'SRLTRANSPORTAD';
const int kAdminIdNumber = 1987;


typedef AdminEntry = ({UserModel user, String? email});

final allAdminsProvider = FutureProvider<List<AdminEntry>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final res = await Supabase.instance.client
      .from(SupabaseConstants.tableUsers)
      .select('id, user_id, full_name, mobile, email, role, company_code, is_first_login, is_active, sequential_num, created_at')
      .eq('company_code', user.companyCode)
      .eq('role', 'admin')
      .order('created_at');
  return (res as List).map((e) {
    final m = Map<String, dynamic>.from(e);
    return (user: UserModel.fromJson(m), email: m['email'] as String?);
  }).toList();
});

class ManageAdminsScreen extends ConsumerWidget {
  const ManageAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).value;
    final admins = ref.watch(allAdminsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Admins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add admin',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => const _AddAdminSheet(),
            ),
          ),
        ],
      ),
      body: admins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load admins: $e')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(allAdminsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = list[i].user;
              final isMe = a.userId == me?.userId;
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.brandYellow,
                    foregroundColor: AppColors.ink,
                    child: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  title: Text(isMe ? '${a.fullName} (You)' : a.fullName),
                  subtitle: Text('${a.userId}\n${a.mobile}'),
                  isThreeLine: true,
                  trailing: isMe
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                          tooltip: 'Remove admin',
                          onPressed: () => _remove(context, ref, a),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, UserModel admin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove admin?'),
        content: Text('${admin.fullName} (${admin.userId}) will be logged out and can no longer log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = Supabase.instance.client;
      await client.rpc('admin_logout_user', params: {'p_user_id': admin.userId});
      await client.from(SupabaseConstants.tableUsers).delete().eq('user_id', admin.userId);
      ref.invalidate(allAdminsProvider);
      messenger.showSnackBar(SnackBar(content: Text('${admin.fullName} removed'), backgroundColor: AppColors.successGreen));
    } catch (e) {
      final msg = e is PostgrestException ? e.message : e.toString();
      messenger.showSnackBar(SnackBar(content: Text('Could not remove: $msg'), backgroundColor: AppColors.errorRed));
    }
  }
}

class _AddAdminSheet extends ConsumerStatefulWidget {
  const _AddAdminSheet();

  @override
  ConsumerState<_AddAdminSheet> createState() => _AddAdminSheetState();
}

class _AddAdminSheetState extends ConsumerState<_AddAdminSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  /// First 2 letters of the first name, e.g. "Ajay Sharma" → "AJ"
  String _initials(String fullName) {
    final first = fullName.trim().split(RegExp(r'\s+')).first.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    return first.length >= 2 ? first.substring(0, 2) : first.padRight(2, 'X');
  }

  /// e.g. Ajay → SRLTRANSPORTADAJ@1987. Returns null if that ID is already taken.
  Future<String?> _newAdminId(String fullName) async {
    final id = '$kAdminIdPrefix${_initials(fullName)}@$kAdminIdNumber';
    final taken = await Supabase.instance.client
        .from(SupabaseConstants.tableUsers)
        .select('user_id')
        .ilike('user_id', id)
        .maybeSingle();
    return taken == null ? id : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final me = ref.read(authStateProvider).value!;
      final client = Supabase.instance.client;
      final mobile = _mobile.text.trim();
      final taken = await client.from(SupabaseConstants.tableUsers).select('user_id').eq('mobile', mobile).maybeSingle();
      if (taken != null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('This mobile number is already registered with another user'),
          backgroundColor: AppColors.errorRed,
        ));
        setState(() => _saving = false);
        return;
      }
      final userId = await _newAdminId(_name.text);
      if (userId == null) {
        messenger.showSnackBar(SnackBar(
          content: Text('Admin ID $kAdminIdPrefix${_initials(_name.text)}@$kAdminIdNumber already exists '
              '(another admin\'s first name starts with the same 2 letters)'),
          backgroundColor: AppColors.errorRed,
        ));
        setState(() => _saving = false);
        return;
      }
      final mpin = '${1000 + Random().nextInt(9000)}';
      await client.from(SupabaseConstants.tableUsers).insert({
        'user_id': userId,
        'full_name': _name.text.trim(),
        'mobile': mobile,
        'role': 'admin',
        'company_code': me.companyCode,
        'mpin_hash': sha256.convert(utf8.encode(mpin)).toString(),
        'is_first_login': false,
        'is_active': true,
        'sequential_num': 1,
      });
      UsageLog.track('admin_added');
      ref.invalidate(allAdminsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Admin Added Successfully'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share these credentials with the admin:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              SelectableText('User ID: $userId', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText('Login PIN: $mpin', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'User ID: $userId\nLogin PIN: $mpin'));
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                  content: Text('Credentials copied to clipboard'),
                  backgroundColor: AppColors.successGreen,
                ));
              },
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
          ],
        ),
      );
      navigator.pop();
    } catch (e) {
      final msg = e is PostgrestException ? e.message : e.toString();
      messenger.showSnackBar(SnackBar(content: Text('Failed to add admin: $msg'), backgroundColor: AppColors.errorRed));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter the admin\'s name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Mobile number'),
                validator: (v) => (v == null || v.trim().length != 10) ? 'Enter a 10-digit mobile number' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandYellow,
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ADD ADMIN'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

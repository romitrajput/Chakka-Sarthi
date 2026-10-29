import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

/// Key used to remember the business name on this phone, so it can be shown
/// on the login screen before anyone has signed in.
const String _businessNamePrefsKey = 'business_name';

/// Names that mean "not set yet" (the setup script's default included).
bool isPlaceholderBusinessName(String? name) {
  if (name == null) return true;
  final n = name.trim().toLowerCase();
  return n.isEmpty || n == 'my transport company';
}

/// The last business name this phone has seen, or null.
Future<String?> cachedBusinessName() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_businessNamePrefsKey);
    return isPlaceholderBusinessName(name) ? null : name;
  } catch (_) {
    return null;
  }
}

/// The signed-in user's business name (from the `companies` table).
/// Returns null when the admin has not entered one yet.
final businessNameProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return cachedBusinessName();

  try {
    final row = await Supabase.instance.client
        .from(SupabaseConstants.tableCompanies)
        .select('company_name')
        .eq('company_code', user.companyCode)
        .maybeSingle();
    final name = row?['company_name'] as String?;
    if (isPlaceholderBusinessName(name)) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessNamePrefsKey, name!.trim());
    return name.trim();
  } catch (_) {
    // Offline or table error: fall back to what this phone remembers
    return cachedBusinessName();
  }
});

/// Saves the business name for the admin's company and refreshes it everywhere.
Future<void> saveBusinessName(WidgetRef ref, String companyCode, String name) async {
  final clean = name.trim();
  await Supabase.instance.client
      .from(SupabaseConstants.tableCompanies)
      .update({'company_name': clean})
      .eq('company_code', companyCode);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_businessNamePrefsKey, clean);
  ref.invalidate(businessNameProvider);
}

/// Asks the admin for the business name and saves it.
/// [required] = first-time prompt (no Cancel button, can't be dismissed).
/// Returns the saved name, or null if cancelled.
Future<String?> showBusinessNameDialog(
  BuildContext context,
  WidgetRef ref, {
  String? current,
  bool required = false,
}) async {
  final user = ref.read(authStateProvider).value;
  if (user == null || user.role != 'admin') return null;

  final controller = TextEditingController(text: current ?? '');
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String? error;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: !required,
    builder: (ctx) => PopScope(
      canPop: !required,
      child: StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(required ? 'What is your business called?' : 'Business name'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (required)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'This name is shown at the top of the app for you and your drivers, and on PDF reports. You can change it later by tapping it.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Shree Ganesh Transport',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) return 'Please enter your business name';
                    if (isPlaceholderBusinessName(v)) return 'Please enter your real business name';
                    return null;
                  },
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await saveBusinessName(ref, user.companyCode, controller.text);
                        if (ctx.mounted) Navigator.pop(ctx, controller.text.trim());
                      } catch (e) {
                        setState(() {
                          saving = false;
                          error = 'Could not save. Check your internet and try again.';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
  return result;
}

/// App-bar title: brand icon + business name, with "Chakka Saarthi" underneath.
/// For admins, tapping the name lets them change it.
class BusinessAppBarTitle extends ConsumerWidget {
  const BusinessAppBarTitle({super.key, this.editable = false});

  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(businessNameProvider).value;
    final title = Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/images/chakka_saarthi_icon.png', width: 34, height: 34),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name ?? (editable ? 'Tap to add business name' : 'Chakka Saarthi'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (name != null)
                const Text(
                  'Chakka Saarthi',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70),
                ),
            ],
          ),
        ),
        if (editable) ...[
          const SizedBox(width: 4),
          const Icon(Icons.edit, size: 14, color: Colors.white70),
        ],
      ],
    );
    if (!editable) return title;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showBusinessNameDialog(context, ref, current: name),
      child: title,
    );
  }
}

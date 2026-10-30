import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

/// Active drivers whose licence has expired or expires within 30 days (soonest first).
final expiringLicencesProvider = FutureProvider<List<UserModel>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.role != 'admin') return [];
  final cutoff = DateTime.now().add(const Duration(days: 30));
  final rows = await Supabase.instance.client
      .from(SupabaseConstants.tableUsers)
      .select('id, user_id, full_name, mobile, role, company_code, is_first_login, is_active, sequential_num, created_at, license_expiry')
      .eq('company_code', user.companyCode)
      .eq('role', 'driver')
      .eq('is_active', true)
      .lte('license_expiry', DateFormat('yyyy-MM-dd').format(cutoff))
      .order('license_expiry');
  return (rows as List).map((r) => UserModel.fromJson(r as Map<String, dynamic>)).toList();
});

/// "Expires 12 Nov 2026 (in 13 days)", "Expired 3 days ago", "Not set".
String licenceStatusText(UserModel driver) {
  final exp = driver.licenseExpiry;
  final days = driver.licenseDaysLeft;
  if (exp == null || days == null) return 'Not set';
  final date = DateFormat('dd MMM yyyy').format(exp);
  if (days < 0) return 'Licence expired $date (${-days} day${days == -1 ? '' : 's'} ago)';
  if (days == 0) return 'Licence expires today';
  return 'Licence expires $date (in $days day${days == 1 ? '' : 's'})';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

/// user_id → full name, for everyone in the signed-in user's company.
final driverNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return {};
  final rows = await Supabase.instance.client
      .from(SupabaseConstants.tableUsers)
      .select('user_id, full_name')
      .eq('company_code', user.companyCode);
  return {
    for (final r in (rows as List).cast<Map<String, dynamic>>())
      r['user_id'] as String: r['full_name'] as String,
  };
});

/// The driver's name for a user ID (falls back to the ID while loading or if not found).
/// Screens that use this also `ref.watch(driverNamesProvider)` in build so they
/// redraw once the names arrive.
String driverNameOf(WidgetRef ref, String userId) {
  return ref.read(driverNamesProvider).value?[userId] ?? userId;
}

/// Shows a driver's name for a user ID.
class DriverName extends ConsumerWidget {
  const DriverName(this.userId, {super.key, this.prefix = '', this.style});

  final String userId;
  final String prefix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(driverNamesProvider).value?[userId] ?? userId;
    return Text('$prefix$name', style: style);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

class UserIdGenerator {
  /// Driver ID = company short code + "DR" + driver's first name + running number.
  /// Example: Sanjay Roadlines (short code SRL), driver Bhavesh Ola, 3rd user → SRLDRBHAVESH003
  /// The short code is set by the admin in Settings → Business name.
  static Future<String> generate({
    required String stateCode,
    required String companyCode,
    required String role,
    required String companyShortName,
    String? fullName,
  }) async {
    final roleCode = role.toLowerCase() == 'admin' ? 'AD' : 'DR';
    final shortCode = companyShortName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final firstName = (fullName ?? '').trim().split(RegExp(r'\s+')).first
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    final namePart = firstName.length > 10 ? firstName.substring(0, 10) : firstName;
    final prefix = '$shortCode$roleCode$namePart';

    int nextSequence = 1;
    try {
      final response = await Supabase.instance.client
          .from(SupabaseConstants.tableUsers)
          .select('sequential_num')
          .eq('company_code', companyCode)
          .order('sequential_num', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response != null) {
        nextSequence = ((response['sequential_num'] as int?) ?? 0) + 1;
      }
    } catch (_) {}

    return '$prefix${nextSequence.toString().padLeft(3, '0')}';
  }
}

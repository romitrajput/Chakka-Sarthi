import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

class UserIdGenerator {
  static Future<String> generate({
    required String stateCode,
    required String companyCode,
    required String role,
    required String companyShortName,
  }) async {
    final roleCode = role.toLowerCase() == 'admin' ? 'AD' : 'DR';
    final prefix = '$stateCode$companyCode$roleCode$companyShortName';

    try {
      final response = await Supabase.instance.client
          .from(SupabaseConstants.tableUsers)
          .select('sequential_num')
          .eq('company_code', companyCode)
          .order('sequential_num', ascending: false)
          .limit(1)
          .maybeSingle();

      int nextSequence = 1;
      if (response != null) {
        nextSequence = (response['sequential_num'] as int) + 1;
      }

      final sequenceStr = nextSequence.toString().padLeft(4, '0');
      return '$prefix$sequenceStr';
    } catch (e) {
      return '${prefix}0001';
    }
  }
}

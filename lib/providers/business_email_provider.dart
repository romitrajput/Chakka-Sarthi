import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/core/utils/app_updater.dart';
import 'package:sanjay_roadlines_fleet/core/utils/usage_log.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';

/// Chakka Saarthi support team
const String kSupportEmail = 'cs.usersupport@gmail.com';

/// Business email (Forgot Login PIN codes and backups go here) + last backup time.
final businessEmailProvider = FutureProvider<({String? email, DateTime? lastBackup})>((ref) async {
  ref.watch(businessDetailsVersion);
  final user = ref.watch(authStateProvider).value;
  if (user == null) return (email: null, lastBackup: null);
  final row = await Supabase.instance.client
      .from(SupabaseConstants.tableCompanies)
      .select('business_email, last_backup_at')
      .eq('company_code', user.companyCode)
      .maybeSingle();
  final last = row?['last_backup_at'] as String?;
  return (
    email: row?['business_email'] as String?,
    lastBackup: last == null ? null : DateTime.tryParse(last)?.toLocal(),
  );
});

/// Emails a zip backup to the business email (only if something changed since the last one).
Future<void> emailBackupNow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing backup email…')));
  try {
    final res = await Supabase.instance.client.functions.invoke('email-backup', body: {'mode': 'manual'});
    final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    messenger.hideCurrentSnackBar();
    if (data['error'] != null) {
      messenger.showSnackBar(SnackBar(content: Text('${data['error']}'), backgroundColor: AppColors.errorRed, duration: const Duration(seconds: 8)));
      return;
    }
    ref.invalidate(businessEmailProvider);
    if (data['skipped'] == true) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No new data since the last backup, so nothing was sent.'),
        backgroundColor: AppColors.accentOrange,
      ));
      UsageLog.track('backup_email', detail: 'no_new_data');
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text('Backup sent to ${data['sent_to']}'),
        backgroundColor: AppColors.successGreen,
      ));
      UsageLog.track('backup_email', detail: 'sent');
    }
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(
      content: Text('Could not send the backup email. Check internet and try again.'),
      backgroundColor: AppColors.errorRed,
    ));
  }
}

/// Opens the phone's / computer's email app addressed to support.
Future<void> contactSupport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final user = ref.read(authStateProvider).value;
  final business = await currentBusinessName(ref);
  final version = await AppUpdater.installedVersion();
  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    query: _query({
      'subject': 'Chakka Saarthi support – $business',
      'body': '\n\n\n---\nBusiness: $business\nUser ID: ${user?.userId ?? '-'}\nApp version: $version',
    }),
  );
  UsageLog.track('support_email');
  final ok = await launchUrl(uri);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(
      content: Text('No email app found. Write to $kSupportEmail'),
      duration: Duration(seconds: 6),
    ));
  }
}

String _query(Map<String, String> params) =>
    params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

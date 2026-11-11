import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/utils/app_updater.dart';
import 'package:sanjay_roadlines_fleet/core/utils/backup_exporter.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/web/desktop_shell.dart';

/// Website settings: business name, data backup, app version.
class DesktopSettingsScreen extends ConsumerStatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  ConsumerState<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends ConsumerState<DesktopSettingsScreen> {
  bool _backingUp = false;

  Future<void> _backup() async {
    setState(() => _backingUp = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await currentBusinessName(ref);
      final (file, summary) = await BackupExporter.buildFullBackup(businessName: name);
      await BackupExporter.share(file, name);
      messenger.showSnackBar(SnackBar(
        content: Text('Backup downloaded ($summary). Keep it somewhere safe, e.g. Google Drive.'),
        backgroundColor: AppColors.successGreen,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.errorRed));
    }
    if (mounted) setState(() => _backingUp = false);
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(businessNameProvider).value;

    Widget item(IconData icon, String title, String subtitle, Widget trailing) => Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.ink),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        );

    return DesktopPage(
      title: 'Settings',
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              item(
                Icons.local_shipping_outlined,
                'Business name',
                business ?? 'Not set yet',
                OutlinedButton(
                  onPressed: () => showBusinessNameDialog(context, ref, current: business),
                  child: const Text('Change'),
                ),
              ),
              item(
                Icons.backup_outlined,
                'Backup data',
                'Download everything (trips, drivers, vehicles…) as one Excel file',
                ElevatedButton(
                  onPressed: _backingUp ? null : _backup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandYellow,
                    foregroundColor: AppColors.ink,
                  ),
                  child: Text(_backingUp ? 'Preparing…' : 'Download backup'),
                ),
              ),
              item(
                Icons.info_outline,
                'App version',
                'The website always runs the newest version',
                FutureBuilder<String>(
                  future: AppUpdater.installedVersion(),
                  builder: (_, snap) => Text(snap.data ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

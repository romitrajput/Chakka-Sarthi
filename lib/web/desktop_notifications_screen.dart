import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/providers/licence_alerts_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/notifications_screen.dart';
import 'package:sanjay_roadlines_fleet/web/desktop_shell.dart';

/// Website: alerts (licence expiry, vehicles in maintenance) next to the trip notifications.
class DesktopNotificationsScreen extends ConsumerWidget {
  const DesktopNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licences = ref.watch(expiringLicencesProvider).value ?? const [];
    final vehicles = ref.watch(vehicleStateProvider).value ?? const [];
    final inWorkshop = vehicles.where((v) => v.status == 'maintenance').toList();
    final date = DateFormat('dd MMM yyyy');

    Widget alert(Color edge, Color bg, String title, String text, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(border: Border(left: BorderSide(color: edge, width: 5))),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        );

    final alerts = [
      for (final d in licences)
        alert(AppColors.errorRed, const Color(0xFFFDECEA), 'Licence ${(d.licenseDaysLeft ?? 0) < 0 ? 'expired' : 'expiring'}',
            '${d.fullName} · ${licenceStatusText(d)}', () => context.go('/admin/manage-drivers')),
      for (final v in inWorkshop)
        alert(
            const Color(0xFFE0A800),
            const Color(0xFFFFF6D6),
            'In maintenance',
            '${v.vehicleNumber}${v.maintenanceReason == null ? '' : ' · ${v.maintenanceReason}'}'
                '${v.maintenanceExpectedReturn == null ? '' : ' · back ${date.format(v.maintenanceExpectedReturn!.toLocal())}'}',
            () => context.go('/admin/maintenance')),
    ];

    return DesktopPage(
      title: 'Notifications & Alerts',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(expiringLicencesProvider);
            ref.invalidate(vehicleStateProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip notifications (same list as the phone app)
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: const NotificationsScreen(),
              ),
            ),
            const SizedBox(width: 20),
            // Alerts
            SizedBox(
              width: 380,
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Alerts (${alerts.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (alerts.isEmpty)
                        const Text('No alerts. All licences are valid and no vehicle is in maintenance.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ...alerts,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

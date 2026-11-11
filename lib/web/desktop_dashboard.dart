import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/driver_names_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';
import 'package:sanjay_roadlines_fleet/screens/admin/manage_drivers_screen.dart' show allDriversProvider;
import 'package:sanjay_roadlines_fleet/web/desktop_shell.dart';
import 'package:sanjay_roadlines_fleet/web/desktop_trips_screen.dart';
import 'package:sanjay_roadlines_fleet/web/trips_data.dart';

/// Website dashboard: key numbers in one row and the latest trips.
class DesktopDashboard extends ConsumerStatefulWidget {
  const DesktopDashboard({super.key});

  @override
  ConsumerState<DesktopDashboard> createState() => _DesktopDashboardState();
}

class _DesktopDashboardState extends ConsumerState<DesktopDashboard> {
  bool _askedName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askBusinessNameIfMissing());
  }

  Future<void> _askBusinessNameIfMissing() async {
    if (_askedName) return;
    _askedName = true;
    final name = await ref.read(businessNameProvider.future).catchError((_) => null);
    if (name == null && mounted) {
      await showBusinessNameDialog(context, ref, required: true);
    }
  }

  void _refresh() {
    ref.invalidate(ticketStateProvider);
    ref.invalidate(vehicleStateProvider);
    ref.invalidate(completedTicketsProvider);
    ref.invalidate(allTripsProvider);
    ref.invalidate(driverNamesProvider);
    ref.invalidate(allDriversProvider);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleStateProvider).value ?? const [];
    final active = ref.watch(ticketStateProvider).value ?? const [];
    final completed = ref.watch(completedTicketsProvider).value ?? const [];
    final names = ref.watch(driverNamesProvider).value ?? const <String, String>{};
    final trips = ref.watch(allTripsProvider);
    final business = ref.watch(businessNameProvider).value;
    final now = DateTime.now();
    final completedToday = completed.where((t) {
      final c = t.completedAt?.toLocal();
      return c != null && c.year == now.year && c.month == now.month && c.day == now.day;
    }).length;
    final driverCount = ref.watch(allDriversProvider).value?.where((d) => d.isActive).length ?? 0;

    final stats = <(String, int, IconData, String)>[
      ('Vehicles', vehicles.length, Icons.directions_car_filled_outlined, '/admin/manage-vehicles'),
      ('Available', vehicles.where((v) => v.status == 'available').length, Icons.check_circle_outline, '/admin/vehicles-available'),
      ('In transit', active.length, Icons.local_shipping_outlined, '/admin/trips'),
      ('Maintenance', vehicles.where((v) => v.status == 'maintenance').length, Icons.build_outlined, '/admin/maintenance'),
      ('Completed today', completedToday, Icons.flag_outlined, '/admin/trips'),
      ('Drivers', driverCount, Icons.people_outline, '/admin/manage-drivers'),
    ];

    return DesktopPage(
      title: business == null ? 'Dashboard' : 'Dashboard · $business',
      actions: [
        IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const gap = 14.0;
              final perRow = c.maxWidth >= 1100 ? 6 : 3;
              final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in stats)
                    SizedBox(
                      width: w,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.go(s.$4),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(s.$1,
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    ),
                                    Icon(s.$3, size: 18, color: AppColors.textSecondary),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${s.$2}',
                                    style: const TextStyle(
                                        fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.ink)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 6),
                  child: Row(
                    children: [
                      const Text('Recent trips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(onPressed: () => context.go('/admin/trips'), child: const Text('View all →')),
                    ],
                  ),
                ),
                trips.when(
                  loading: () => const Padding(padding: EdgeInsets.all(24), child: LinearProgressIndicator()),
                  error: (e, _) => Padding(padding: const EdgeInsets.all(18), child: Text('Could not load trips: $e')),
                  data: (rows) => rows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No trips yet. Use "Create Trip" in the menu.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : TripsTable(rows: rows.take(10).toList(), names: names),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/notification_bell.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/vehicle_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/licence_alerts_provider.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';
import 'package:sanjay_roadlines_fleet/core/utils/backup_exporter.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  bool _checkedBusinessName = false;
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();
    // Show the welcome card for 6 seconds after login, then animate it away
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showWelcome = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The admin side is always English, whatever a driver chose on this phone
      ref.read(languageProvider.notifier).state = const Locale('en');
      _askBusinessNameIfMissing();
    });
  }

  /// First time an admin opens the app, ask for the business name.
  Future<void> _askBusinessNameIfMissing() async {
    if (_checkedBusinessName) return;
    final user = ref.read(authStateProvider).value;
    if (user == null || user.role != 'admin') return;
    _checkedBusinessName = true;
    try {
      ref.invalidate(businessNameProvider); // always show the latest saved name
      ref.invalidate(expiringLicencesProvider); // fresh licence alerts
      final name = await ref.read(businessNameProvider.future);
      if (name == null && mounted) {
        await showBusinessNameDialog(context, ref, required: true);
      }
    } catch (_) {
      // Ignore: the admin can still tap "Tap to add business name" in the header
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final currentLocale = ref.watch(languageProvider);
    if (!_checkedBusinessName && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askBusinessNameIfMissing());
    }

    // Data
    final ticketState = ref.watch(ticketStateProvider);
    final vehicleState = ref.watch(vehicleStateProvider);
    // On a trip = assigned (waiting to load) or already loaded and moving
    final inTransitCount = ticketState.maybeWhen(
      data: (tickets) => tickets.where((t) => t.status == 'assigned' || t.status == 'in_transit').length,
      orElse: () => 0,
    );
    final completedTodayCount = ref.watch(completedTicketsProvider).maybeWhen(
      data: (tickets) {
        final now = DateTime.now();
        return tickets.where((t) =>
            t.status == 'completed' &&
            t.completedAt != null &&
            t.completedAt!.year == now.year &&
            t.completedAt!.month == now.month &&
            t.completedAt!.day == now.day).length;
      },
      orElse: () => 0,
    );
    final totalVehicles = vehicleState.maybeWhen(
      data: (vehicles) => vehicles.length,
      orElse: () => 0,
    );
    final availableCount = vehicleState.maybeWhen(
      data: (vehicles) => vehicles.where((v) => v.status == 'available').length,
      orElse: () => 0,
    );
    final maintenanceCount = vehicleState.maybeWhen(
      data: (vehicles) => vehicles.where((v) => v.status == 'maintenance').length,
      orElse: () => 0,
    );
    final assignedCount = ticketState.maybeWhen(
      data: (tickets) => tickets.where((t) => t.status == 'assigned').length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        titleSpacing: 12,
        title: const BusinessAppBarTitle(editable: true),
        actions: [
          NotificationBell(onTap: () => context.push('/admin/notifications')),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 24),
            tooltip: 'Settings',
            onPressed: () => _showSettings(context, ref),
          ),
        ],
      ),
      body: _buildHomeTab(context, ref, user, currentLocale,
          totalVehicles, inTransitCount, completedTodayCount, maintenanceCount,
          availableCount, assignedCount),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    Locale currentLocale,
    int totalVehicles,
    int inTransitCount,
    int completedTodayCount,
    int maintenanceCount,
    int availableCount,
    int assignedCount,
  ) {
    final expiring = ref.watch(expiringLicencesProvider).value ?? const <UserModel>[];
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () async {
        ref.invalidate(ticketStateProvider);
        ref.invalidate(vehicleStateProvider);
        ref.invalidate(completedTicketsProvider);
        ref.invalidate(expiringLicencesProvider);
      },
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ===== Welcome Banner (shows briefly after login, then slides away) =====
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 650),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
            ),
            child: _showWelcome
                ? KeyedSubtree(
                    key: const ValueKey('welcome'),
                    child:
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back,',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${user?.fullName ?? "Admin"} 👋',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Here's what's happening with your fleet today.",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Truck illustration
                        Container(
                          width: 64,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            size: 36,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                  )
                : const SizedBox(key: ValueKey('no-welcome'), width: double.infinity),
          ),

          const SizedBox(height: 16),

          // ===== Fleet Overview (stays at the top) =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
            // Fleet Overview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Fleet Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Donut chart
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            segments: [
                              _ChartSegment(inTransitCount.toDouble(), AppColors.brandYellow),
                              _ChartSegment(availableCount.toDouble(), AppColors.goGreen),
                              _ChartSegment(completedTodayCount.toDouble(), AppColors.roadGrey),
                              _ChartSegment(maintenanceCount.toDouble(), AppColors.workshopOrange),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$totalVehicles',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                const Text('vehicles', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem('In Transit', '$inTransitCount', AppColors.brandYellow),
                            _buildLegendItem('Available', '$availableCount', AppColors.goGreen),
                            _buildLegendItem('Completed', '$completedTodayCount', AppColors.roadGrey),
                            _buildLegendItem('Maintenance', '$maintenanceCount', AppColors.workshopOrange),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ===== Status row: four equal tiles =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatItem('Vehicles', '$totalVehicles', Icons.directions_car_filled_outlined, AppColors.ink, AppColors.mist),
                  const SizedBox(width: 8),
                  _buildStatItem('In Transit', '$inTransitCount', Icons.local_shipping_outlined, AppColors.warningYellow, AppColors.inTransitBg),
                  const SizedBox(width: 8),
                  _buildStatItem('Completed', '$completedTodayCount', Icons.check_circle_outline, AppColors.successGreen, AppColors.availableBg),
                  const SizedBox(width: 8),
                  _buildStatItem('Maintenance', '$maintenanceCount', Icons.build_outlined, const Color(0xFFA33A00), AppColors.maintenanceBg),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ===== Main action: Create New Trip =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: AppColors.brandYellow,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/admin/create-ticket'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add, color: AppColors.brandYellow, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create New Trip', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            SizedBox(height: 2),
                            Text('Assign a vehicle and driver', style: TextStyle(fontSize: 13, color: AppColors.ink)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.ink),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ===== Licence expiry alert (only when something needs attention) =====
          Builder(builder: (context) {
            if (expiring.isEmpty) return const SizedBox.shrink();
            final expired = expiring.where((d) => (d.licenseDaysLeft ?? 1) < 0).length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Material(
                color: AppColors.cancelledBg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push('/admin/manage-drivers'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, color: AppColors.errorRed),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expired > 0
                                    ? '$expired driving licence${expired == 1 ? '' : 's'} expired'
                                    : '${expiring.length} driving licence${expiring.length == 1 ? '' : 's'} expiring soon',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.errorRed),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                expiring.take(3).map((d) => d.fullName).join(', ') + (expiring.length > 3 ? '…' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.errorRed),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // ===== Tiles: two equal columns =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _tileRow(
                  _buildMenuCard(Icons.local_shipping_outlined, 'In Transit', 'Ongoing trips',
                      () => context.push('/admin/in-transit'),
                      badge: inTransitCount, badgeBg: AppColors.inTransitBg, badgeFg: AppColors.warningYellow),
                  _buildMenuCard(Icons.swap_horiz, 'Re-assign Driver', 'Active trips',
                      () => context.push('/admin/assigned-tickets'),
                      badge: assignedCount, badgeBg: Colors.white, badgeFg: AppColors.ink, badgeOutlined: true),
                ),
                const SizedBox(height: 10),
                _tileRow(
                  _buildMenuCard(Icons.check_circle_outline, 'Completed Trips', 'Trip history',
                      () => context.push('/admin/completed-trips'),
                      badge: completedTodayCount, badgeBg: AppColors.completedBg, badgeFg: AppColors.roadGrey),
                  _buildMenuCard(Icons.build_outlined, 'Maintenance', 'Vehicles in the workshop',
                      () => context.push('/admin/maintenance'),
                      badge: maintenanceCount, badgeBg: AppColors.maintenanceBg, badgeFg: const Color(0xFFA33A00)),
                ),
                const SizedBox(height: 10),
                _tileRow(
                  _buildMenuCard(Icons.directions_car_filled_outlined, 'Vehicles', 'Available & maintenance',
                      () => context.push('/admin/vehicles-available'),
                      badge: availableCount, badgeBg: AppColors.availableBg, badgeFg: AppColors.successGreen),
                  _buildMenuCard(Icons.bar_chart_rounded, 'Reports', 'Summary & PDF export',
                      () => context.push('/admin/reports')),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    ),
    );
  }

  /// Two tiles side by side, always the same height.
  Widget _tileRow(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: left), const SizedBox(width: 10), Expanded(child: right)],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, Color tint) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    int? badge,
    Color badgeBg = AppColors.mist,
    Color badgeFg = AppColors.ink,
    bool badgeOutlined = false,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 24, color: AppColors.ink),
                  const Spacer(),
                  if (badge != null && badge > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 26),
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(13),
                        border: badgeOutlined ? Border.all(color: AppColors.ink, width: 1.5) : null,
                      ),
                      child: Text('$badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeFg)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink))),
          Text(count, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primaryDark),
                title: const Text('Business name'),
                subtitle: Text(
                  ref.read(businessNameProvider).value ?? 'Not set yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final saved = await showBusinessNameDialog(
                    context,
                    ref,
                    current: ref.read(businessNameProvider).value,
                  );
                  if (saved != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Business name updated to "$saved"'),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: AppColors.primaryDark),
                title: const Text('Manage Drivers'),
                subtitle: const Text('Add, view & remove drivers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/admin/manage-drivers');
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primaryDark),
                title: const Text('Manage Vehicles'),
                subtitle: const Text('Add, import & remove vehicles'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/admin/manage-vehicles');
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined, color: AppColors.primaryDark),
                title: const Text('Backup data'),
                subtitle: const Text('Download everything as an Excel file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runBackup(context);
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.errorRed),
                title: const Text('Log out', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmLogout(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Preparing backup…')),
          ],
        ),
      ),
    );
    bool dialogOpen = true;
    try {
      final name = await currentBusinessName(ref);
      final (file, summary) = await BackupExporter.buildFullBackup(businessName: name);
      navigator.pop(); // close "preparing" before the share sheet opens
      dialogOpen = false;
      await BackupExporter.share(file, name);
      messenger.showSnackBar(SnackBar(
        content: Text('Backup ready ($summary). Save it somewhere safe, e.g. Google Drive.'),
        backgroundColor: AppColors.successGreen,
      ));
    } catch (e) {
      if (dialogOpen) navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.errorRed));
    }
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
      ],
    );
  }
}

// Donut Chart Painter
class _ChartSegment {
  final double value;
  final Color color;
  _ChartSegment(this.value, this.color);
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSegment> segments;

  _DonutChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold(0.0, (sum, s) => sum + s.value);
    if (total == 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2),
        0,
        2 * math.pi,
        false,
        Paint()..color = AppColors.divider..style = PaintingStyle.stroke..strokeWidth = 18,
      );
      return;
    }

    double startAngle = -math.pi / 2;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2);

    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweepAngle = (segment.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

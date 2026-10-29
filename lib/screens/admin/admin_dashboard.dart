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
    // Show the welcome card for ~1.5 seconds after login, then animate it away
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showWelcome = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askBusinessNameIfMissing());
  }

  /// First time an admin opens the app, ask for the business name.
  Future<void> _askBusinessNameIfMissing() async {
    if (_checkedBusinessName) return;
    final user = ref.read(authStateProvider).value;
    if (user == null || user.role != 'admin') return;
    _checkedBusinessName = true;
    try {
      ref.invalidate(businessNameProvider); // always show the latest saved name
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
    final inTransitCount = ticketState.maybeWhen(
      data: (tickets) => tickets.where((t) => t.status == 'in_transit').length,
      orElse: () => 0,
    );
    final completedTodayCount = ticketState.maybeWhen(
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
    return SingleChildScrollView(
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
                      const Text('Fleet Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
                              _ChartSegment(inTransitCount.toDouble(), const Color(0xFF27AE60)),
                              _ChartSegment(availableCount.toDouble(), const Color(0xFF2874A6)),
                              _ChartSegment(completedTodayCount.toDouble(), const Color(0xFF8E44AD)),
                              _ChartSegment(maintenanceCount.toDouble(), const Color(0xFFE67E22)),
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
                                const Text('Total\nVehicles', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                            _buildLegendItem('In Transit', '$inTransitCount', const Color(0xFF27AE60)),
                            _buildLegendItem('Available', '$availableCount', const Color(0xFF2874A6)),
                            _buildLegendItem('Completed', '$completedTodayCount', const Color(0xFF8E44AD)),
                            _buildLegendItem('Maintenance', '$maintenanceCount', const Color(0xFFE67E22)),
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

          // ===== Stats Row =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatItem('Total Vehicles', '$totalVehicles', Icons.directions_car_filled, AppColors.primaryDark),
                const SizedBox(width: 8),
                _buildStatItem('In Transit', '$inTransitCount', Icons.local_shipping_outlined, AppColors.accentOrange),
                const SizedBox(width: 8),
                _buildStatItem('Completed', '$completedTodayCount', Icons.check_circle_outline, AppColors.successGreen),
                const SizedBox(width: 8),
                _buildStatItem('Maintenance', '$maintenanceCount', Icons.build_circle_outlined, AppColors.errorRed),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== Cards Grid — Wrap layout so cards grow with content =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final spacing = 10.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                final cards = <Widget>[
                  _buildMenuCard(
                    context,
                    'Create New Trip',
                    'Plan & create a new trip',
                    Icons.add_road,
                    const Color(0xFF1B4F72),
                    () => context.push('/admin/create-ticket'),
                  ),
                  _buildMenuCard(
                    context,
                    'Re-assign Driver',
                    'Reassign active trips',
                    Icons.swap_horiz,
                    const Color(0xFFE67E22),
                    () => context.push('/admin/assigned-tickets'),
                    badge: assignedCount,
                  ),
                  _buildMenuCard(
                    context,
                    'In Transit',
                    'View ongoing trips',
                    Icons.local_shipping_outlined,
                    const Color(0xFFE67E22),
                    () => context.push('/admin/in-transit'),
                    badge: inTransitCount,
                  ),
                  _buildMenuCard(
                    context,
                    'Completed Trips',
                    'View trip history',
                    Icons.task_alt,
                    const Color(0xFF27AE60),
                    () => context.push('/admin/completed-trips'),
                    badge: completedTodayCount,
                  ),
                  _buildMenuCard(
                    context,
                    'Vehicles',
                    'Available & maintenance',
                    Icons.directions_car_filled,
                    const Color(0xFF2874A6),
                    () => context.push('/admin/vehicles-available'),
                    badge: availableCount,
                  ),
                  _buildMenuCard(
                    context,
                    'Maintenance',
                    'Manage vehicle maintenance',
                    Icons.build_circle_outlined,
                    const Color(0xFFE67E22),
                    () => context.push('/admin/maintenance'),
                    badge: maintenanceCount,
                  ),
                  _buildMenuCard(
                    context,
                    'Dashboard',
                    'Analytics & fleet overview',
                    Icons.analytics_outlined,
                    const Color(0xFF8E44AD),
                    () => context.push('/admin/reports'),
                  ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ===== Recent Alerts =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Recent Alerts
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (maintenanceCount > 0)
                        _buildAlertItem(
                          Icons.build_circle_outlined,
                          'Maintenance due',
                          '$maintenanceCount vehicle(s)',
                          AppColors.errorRed,
                        ),
                      if (assignedCount > 0)
                        _buildAlertItem(
                          Icons.assignment_outlined,
                          'Pending trips',
                          '$assignedCount trip(s) assigned',
                          AppColors.accentOrange,
                        ),
                      if (inTransitCount > 0)
                        _buildAlertItem(
                          Icons.local_shipping_outlined,
                          'In transit',
                          '$inTransitCount trip(s) active',
                          AppColors.primaryDark,
                        ),
                      if (maintenanceCount == 0 && assignedCount == 0 && inTransitCount == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, size: 36, color: AppColors.successGreen.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                const Text('All clear!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.08),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, {int? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3)),
                ],
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
            if (badge == null || badge == 0)
              Icon(Icons.arrow_forward_ios, size: 10, color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
          Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAlertItem(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
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
                leading: const Icon(Icons.storefront_outlined, color: AppColors.primaryDark),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
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

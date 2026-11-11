import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanjay_roadlines_fleet/app.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/utils/app_updater.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/notification_provider.dart';

/// The admin website switches to the full-screen layout from this browser width.
const double kDesktopMinWidth = 1000;

bool isDesktopWeb(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kDesktopMinWidth;

/// Shows [desktop] on a wide browser window, otherwise the phone screen [mobile].
class ResponsiveSwitch extends StatelessWidget {
  const ResponsiveSwitch({super.key, required this.desktop, required this.mobile});
  final Widget desktop;
  final Widget mobile;

  @override
  Widget build(BuildContext context) => isDesktopWeb(context) ? desktop : mobile;
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

const _mainItems = [
  _NavItem('Dashboard', Icons.space_dashboard_outlined, '/admin/dashboard'),
  _NavItem('Create Trip', Icons.add_road, '/admin/create-ticket'),
  _NavItem('Trips', Icons.local_shipping_outlined, '/admin/trips'),
  _NavItem('Re-assign', Icons.swap_horiz, '/admin/assigned-tickets'),
  _NavItem('Vehicles', Icons.directions_car_filled_outlined, '/admin/manage-vehicles'),
  _NavItem('Maintenance', Icons.build_outlined, '/admin/maintenance'),
  _NavItem('Drivers', Icons.people_outline, '/admin/manage-drivers'),
  _NavItem('Admins', Icons.admin_panel_settings_outlined, '/admin/manage-admins'),
  _NavItem('Reports', Icons.bar_chart_rounded, '/admin/reports'),
  _NavItem('Notifications & Alerts', Icons.notifications_outlined, '/admin/notifications'),
];

/// Pages that are designed for the full width; every other admin page is the
/// phone screen, shown at a comfortable width in the middle.
const _fullWidthRoutes = {'/admin/dashboard', '/admin/trips', '/admin/notifications', '/admin/settings'};

/// Wraps the whole website: left menu for admins on a wide window,
/// phone-style centred column everywhere else.
class DesktopFrame extends ConsumerWidget {
  const DesktopFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb) return child;
    final router = ref.watch(routerProvider);
    final user = ref.watch(authStateProvider).value;
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        final wide = MediaQuery.sizeOf(context).width >= kDesktopMinWidth;
        if (!wide || user == null || user.role != 'admin' || !path.startsWith('/admin')) {
          return ColoredBox(
            color: AppColors.ink,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ClipRect(child: child),
              ),
            ),
          );
        }
        final content = _fullWidthRoutes.contains(path)
            ? child
            : ColoredBox(
                color: const Color(0xFFE9E9E3),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ClipRect(child: child),
                  ),
                ),
              );
        return Row(
          children: [
            _DesktopNav(path: path, router: router),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _DesktopNav extends ConsumerWidget {
  const _DesktopNav({required this.path, required this.router});
  final String path;
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationStreamProvider).value?.where((n) => !n.isRead).length ?? 0;
    return Material(
      color: AppColors.ink,
      child: SizedBox(
        width: 248,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset('assets/images/chakka_saarthi_icon.png', width: 34, height: 34),
                      ),
                      const SizedBox(width: 10),
                      const Text('Chakka Saarthi',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final item in _mainItems)
                        _tile(item.label, item.icon, path == item.route, () => router.go(item.route),
                            badge: item.route == '/admin/notifications' ? unread : 0),
                    ],
                  ),
                ),
                _tile('Settings', Icons.settings_outlined, path == '/admin/settings',
                    () => router.go('/admin/settings')),
                _tile('Log out', Icons.logout, false, () => _confirmLogout(ref), danger: true),
                const SizedBox(height: 6),
                FutureBuilder<String>(
                  future: AppUpdater.installedVersion(),
                  builder: (_, snap) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(snap.hasData ? 'App version ${snap.data}' : '',
                        style: const TextStyle(color: Color(0xFF7E8296), fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(String label, IconData icon, bool selected, VoidCallback onTap,
      {bool danger = false, int badge = 0}) {
    final fg = selected ? AppColors.ink : (danger ? const Color(0xFFFF8A80) : const Color(0xFFC9CBD6));
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? AppColors.brandYellow : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: fg, fontSize: 14.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(99)),
                    child: Text('$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(WidgetRef ref) {
    final ctx = router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authStateProvider.notifier).logout();
              router.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

/// Top bar + content area used by the full-width admin pages.
class DesktopPage extends StatelessWidget {
  const DesktopPage({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE6E6E0))),
            ),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const Spacer(),
                ...actions,
                const SizedBox(width: 16),
                const _WhoAmI(),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _WhoAmI extends ConsumerWidget {
  const _WhoAmI();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();
    final parts = user.fullName.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
    return Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
            Text(user.userId, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.brandYellow,
          foregroundColor: AppColors.ink,
          child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_translations.dart';
import 'package:sanjay_roadlines_fleet/core/utils/translation_service.dart';
import 'package:sanjay_roadlines_fleet/core/widgets/notification_bell.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/notification_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/ticket_provider.dart';
import 'package:sanjay_roadlines_fleet/core/utils/local_notification_service.dart';
import 'package:sanjay_roadlines_fleet/repositories/auth_repository.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/app.dart';

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    // Fetch the latest business name (the admin may have changed it)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(businessNameProvider);
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
      if (enabled) {
        LocalNotificationService.initialize();
        final userId = ref.read(authStateProvider).value?.userId;
        if (userId != null) {
          LocalNotificationService.startListening(userId);
        }
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() => _notificationsEnabled = value);
      if (value) {
        LocalNotificationService.initialize();
        final userId = ref.read(authStateProvider).value?.userId;
        if (userId != null) {
          LocalNotificationService.startListening(userId);
        }
      } else {
        LocalNotificationService.stopListening();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Helper to get translated string
  String _tr(String key) {
    final locale = ref.read(languageProvider);
    return AppTranslations.translate(key, locale);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final ticketState = ref.watch(ticketStateProvider);
    final currentLocale = ref.watch(languageProvider);
    final screenW = MediaQuery.of(context).size.width;

    final count = ticketState.when(
      data: (tickets) => tickets
          .where((t) => t.status == 'assigned' || t.status == 'in_transit')
          .length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final hasTickets = count > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        titleSpacing: 12,
        title: const BusinessAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white, size: 22),
            onPressed: () => _showLanguageSelection(context, ref),
          ),
          NotificationBell(
            onTap: () {
              ref.read(notificationControllerProvider.notifier).markAllRead();
              _showNotifications(context, ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 22),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: _buildHomeTab(context, ref, user, currentLocale, screenW, count, hasTickets),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    Locale currentLocale,
    double screenW,
    int count,
    bool hasTickets,
  ) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ticketStateProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_tr('hello')}, ${user?.fullName.split(' ').first ?? _tr('driver')} 👋',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasTickets
                                ? '$count ${_tr('tripWaiting')}'
                                : _tr('noActiveTrips'),
                            style: TextStyle(
                              fontSize: 13,
                              color: hasTickets ? AppColors.accentOrange : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: screenW * 0.22,
                      height: screenW * 0.18,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, size: 40, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Assigned Tickets Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => context.push('/driver/assigned-tickets'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B4F72), Color(0xFF2874A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: hasTickets
                            ? ScaleTransition(
                                scale: _pulseAnimation,
                                child: const Icon(Icons.assignment, color: Colors.white, size: 24),
                              )
                            : const Icon(Icons.assignment_outlined, color: Colors.white70, size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _tr('assignedTickets'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasTickets
                            ? '$count ${_tr('inTransit')}'
                            : _tr('noActiveTrips'),
                        style: TextStyle(fontSize: 13, color: hasTickets ? Colors.white : Colors.white60),
                      ),
                      if (!hasTickets) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.notifications_outlined, color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child:                              Text(
                                _tr('notifications'),
                                style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasTickets) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _tr('ok'),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20, color: AppColors.primaryDark),
                        const SizedBox(width: 8),
                        Text(
                          _tr('accountSettings'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_reset, color: AppColors.errorRed, size: 22),
                      title: Text(
                        _tr('resetMpin'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        _tr('resetMpinDesc'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _showResetMpinDialog(context, ref),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notification Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.primaryDark),
                        const SizedBox(width: 8),
                        Text(
                          _tr('notifications'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _tr('popUpNotifications'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        _tr('popUpNotificationsDesc'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      value: _notificationsEnabled,
                      activeThumbColor: AppColors.primaryDark,
                      onChanged: _toggleNotifications,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_tr('logout')),
        content: Text(_tr('logoutConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: Text(_tr('logout')),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(builder: (context, ref, _) {
        final notifs = ref.watch(notificationStreamProvider);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(_tr('notifications'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: notifs.when(
                  data: (allList) {
                    final list = allList.where((n) => !n.isRead).toList();
                    return list.isEmpty
                        ? Center(
                            child: Text(_tr('noUnreadNotifications'),
                                style: const TextStyle(color: AppColors.textSecondary)))
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final n = list[i];
                              return ListTile(
                                leading: Icon(Icons.notifications_outlined, color: n.isRead ? Colors.grey : AppColors.primaryDark),
                                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                                subtitle: Text(n.message, style: const TextStyle(fontSize: 12)),
                              );
                            },
                          );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showResetMpinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_tr('resetMpin')),
        content: Text(_tr('resetMpinConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(authStateProvider).value;
              if (user == null) return;
              final messenger = ScaffoldMessenger.of(context);
              final navigator = GoRouter.of(context);
              try {
                await AuthRepository().resetMpin(user.userId);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(_tr('mpinResetSuccess')),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                  ref.read(authStateProvider.notifier).logout();
                  navigator.go('/login');
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(_tr('mpinResetFailed')), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: Text(_tr('resetMpin')),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelection(BuildContext context, WidgetRef ref) async {
    final currentLocale = ref.read(languageProvider);
    final translationService = TranslationService();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _tr('selectLanguage'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _tr('selectLanguageDesc'),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: supportedLanguages.length,
                    itemBuilder: (context, index) {
                      final lang = supportedLanguages[index];
                      final isSelected = currentLocale.languageCode == lang.code;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryDark.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              lang.code.toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryDark : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          lang.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          lang.nativeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.primaryDark)
                            : FutureBuilder<bool>(
                                future: translationService.isModelDownloaded(lang.mlKitLanguage),
                                builder: (context, snapshot) {
                                  final isDownloaded = snapshot.data ?? false;
                                  if (isDownloaded) {
                                    return const Icon(Icons.download_done, color: AppColors.successGreen, size: 20);
                                  }
                                  return const Icon(Icons.download_outlined, color: Colors.grey, size: 20);
                                },
                              ),
                        onTap: () async {
                          Navigator.pop(ctx);

                          // Show switching indicator
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${_tr('switchingTo')} ${lang.name}...'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppColors.primaryDark,
                              ),
                            );
                          }

                          // Save language preference
                          await AppTranslations.saveLanguage(lang.code);

                          // Initialize translation service
                          await translationService.setTargetLanguage(lang.mlKitLanguage);

                          // Initialize notification translation
                          await LocalNotificationService.initializeTranslation(
                            targetLanguageCode: lang.code,
                          );

                          // Update app locale
                          ref.read(languageProvider.notifier).state = Locale(lang.code);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${_tr('languageChanged')} ${lang.name}'),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/core/utils/push_service.dart';
import 'package:sanjay_roadlines_fleet/core/utils/translation_service.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_notify');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _isInitialized = true;

    // Android 13+ only shows notifications after the user allows them
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // Same channel Firebase uses for notifications that arrive while the app is closed
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'fleet_channel',
        'Trip notifications',
        description: 'Trip assignments, loading and unloading updates',
        importance: Importance.high,
      ));
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'fleet_channel',
      'Fleet Notifications',
      channelDescription: 'Notifications for fleet management events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_notify',
      color: Color(0xFFFFD23F),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  /// IDs of notifications already shown as a pop-up on this phone.
  /// Saved on the phone so a notification pops up only once, ever —
  /// not again every time the app is opened or a screen changes.
  static const String _shownIdsKey = 'shown_notification_ids';
  static Set<String>? _shownIds;
  static String? _listeningFor;

  static Future<Set<String>> _loadShownIds() async {
    if (_shownIds != null) return _shownIds!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _shownIds = (prefs.getStringList(_shownIdsKey) ?? const <String>[]).toSet();
    } catch (_) {
      _shownIds = <String>{};
    }
    return _shownIds!;
  }

  static Future<void> _rememberShown(String id) async {
    final ids = await _loadShownIds();
    ids.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = ids.toList();
      // keep the list small
      await prefs.setStringList(_shownIdsKey, list.length > 300 ? list.sublist(list.length - 300) : list);
    } catch (_) {}
  }

  /// Listen to real-time notifications from Supabase and show as pop-ups
  static void startListening(String targetUserId) {
    // Already listening for this user: don't restart (restarting re-sends the latest notification)
    if (_subscription != null && _listeningFor == targetUserId) return;
    _subscription?.cancel();
    _listeningFor = targetUserId;

    _subscription = Supabase.instance.client
        .from(SupabaseConstants.tableNotifications)
        .stream(primaryKey: ['id'])
        .eq('target_user_id', targetUserId)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((data) async {
          if (data.isEmpty) return;
          final notif = data.first;
          final id = notif['id']?.toString();
          final isRead = notif['is_read'] as bool? ?? false;
          if (id == null || isRead) return;

          final shown = await _loadShownIds();
          if (shown.contains(id)) return; // already popped up once
          await _rememberShown(id);

          // App in the background with Firebase set up: Firebase already shows it
          if (PushService.isReady &&
              WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
            return;
          }

          final title = notif['title'] as String? ?? 'Notification';
          final message = notif['message'] as String? ?? '';
          showNotification(title: title, body: message, id: id.hashCode & 0x7fffffff);
        });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _listeningFor = null;
  }

  static TranslationService? _translationService;

  /// Initialize translation service for notifications
  static Future<void> initializeTranslation({required String targetLanguageCode}) async {
    final targetLang = SupportedLanguage.getLanguageFromCode(targetLanguageCode);
    if (targetLang != null) {
      _translationService = TranslationService();
      await _translationService!.initialize(
        source: TranslateLanguage.english,
        target: targetLang.mlKitLanguage,
      );
    }
  }

  /// Translate text using ML Kit
  static Future<String> _translate(String text) async {
    if (_translationService == null) return text;
    try {
      return await _translationService!.translate(text);
    } catch (e) {
      return text;
    }
  }

  /// Show trip-related notifications with ML Kit translation
  static Future<void> notifyTripStarted(String driverName, String ticketId) async {
    final title = await _translate('Trip Started');
    final body = await _translate('$driverName started trip $ticketId');
    await showNotification(title: '🚛 $title', body: body);
  }

  static Future<void> notifyLoadingCompleted(String driverName, String ticketId) async {
    final title = await _translate('Loading Completed');
    final body = await _translate('$driverName completed loading for trip $ticketId');
    await showNotification(title: '📦 $title', body: body);
  }

  static Future<void> notifyUnloadingCompleted(String driverName, String ticketId) async {
    final title = await _translate('Unloading Completed');
    final body = await _translate('$driverName completed unloading for trip $ticketId');
    await showNotification(title: '📤 $title', body: body);
  }

  static Future<void> notifyReportingDateSubmitted(String driverName, String ticketId) async {
    final title = await _translate('Reporting Date Submitted');
    final body = await _translate('$driverName submitted reporting date for trip $ticketId');
    await showNotification(title: '📅 $title', body: body);
  }

  static Future<void> notifyTripCompleted(String driverName, String ticketId) async {
    final title = await _translate('Trip Completed');
    final body = await _translate('Trip $ticketId completed by $driverName');
    await showNotification(title: '✅ $title', body: body);
  }
}

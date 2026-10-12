import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/core/utils/translation_service.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1B4F72),
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

  /// Listen to real-time notifications from Supabase and show as pop-ups
  static void startListening(String targetUserId) {
    _subscription?.cancel();

    _subscription = Supabase.instance.client
        .from(SupabaseConstants.tableNotifications)
        .stream(primaryKey: ['id'])
        .eq('target_user_id', targetUserId)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((data) {
          if (data.isNotEmpty) {
            final notif = data.first;
            final title = notif['title'] as String? ?? 'Notification';
            final message = notif['message'] as String? ?? '';
            final isRead = notif['is_read'] as bool? ?? false;

            if (!isRead) {
              showNotification(title: title, body: message);
            }
          }
        });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
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

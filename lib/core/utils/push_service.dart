import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notifications that arrive even when the app is closed (Firebase Cloud Messaging).
/// Works only after google-services.json has been added to the build; until then
/// everything here quietly does nothing and the in-app notifications still work.
class PushService {
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (_) {
      _ready = false; // Firebase not set up in this build
    }
  }

  /// After login: save this phone's push address so the server can reach it.
  static Future<void> registerForCurrentUser() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _save(token);
      messaging.onTokenRefresh.listen(_save);
    } catch (_) {}
  }

  static Future<void> _save(String token) async {
    try {
      await Supabase.instance.client.rpc('save_fcm_token', params: {'p_token': token});
    } catch (_) {}
  }
}

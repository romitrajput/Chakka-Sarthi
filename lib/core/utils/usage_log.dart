import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:sanjay_roadlines_fleet/core/utils/app_updater.dart';

/// Private usage log: which admin screens and features are used, and when.
/// Only the event name, screen, time, platform and app version are sent —
/// never names, User IDs, phone numbers or trip details. Stored in a hidden
/// part of the database that no app user can read.
class UsageLog {
  static String? _role;
  static String? _version;
  static final List<Map<String, String>> _queue = [];
  static Timer? _timer;
  static _Flusher? _flusher;
  static String? _lastScreen;

  /// Called when someone logs in or out. Only admins are logged.
  static void setRole(String? role) {
    if (role == _role) return;
    if (_role == 'admin' && role != 'admin') {
      unawaited(flush());
    }
    _role = role;
    _lastScreen = null;
    if (role == 'admin') {
      unawaited(AppUpdater.installedVersion().then((v) => _version = v).catchError((_) => ''));
      _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => flush());
      if (_flusher == null) {
        _flusher = _Flusher();
        WidgetsBinding.instance.addObserver(_flusher!);
      }
      track('session_start');
    }
  }

  /// A screen was opened, e.g. /admin/trips
  static void screen(String path) {
    if (path == _lastScreen) return;
    _lastScreen = path;
    track('screen_view', screen: path);
  }

  /// A feature was used, e.g. trip_created, report_pdf, backup_email
  static void track(String event, {String? screen, String? detail}) {
    if (_role != 'admin') return;
    _queue.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      if (screen != null) 'screen': screen,
      if (screen == null && _lastScreen != null) 'screen': _lastScreen!,
      if (detail != null) 'detail': detail,
      'platform': kIsWeb ? 'web' : 'android',
      if (_version != null) 'app_version': _version!,
    });
    if (_queue.length >= 20) unawaited(flush());
  }

  static Future<void> flush() async {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, String>>.from(_queue.take(50));
    _queue.removeRange(0, batch.length);
    try {
      await Supabase.instance.client.rpc('log_usage', params: {'p_events': batch});
    } catch (_) {
      // Offline or not set up yet: keep a small amount for the next try
      if (_queue.length < 200) _queue.insertAll(0, batch);
    }
  }
}

class _Flusher with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      UsageLog.flush();
    }
  }
}

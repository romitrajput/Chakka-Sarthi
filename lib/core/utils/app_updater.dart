import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';

/// Self-update: every "Build APK" run uploads the new app and a small
/// latest.json to the public "app-releases" storage folder. When a phone has an
/// older build, it offers "Update", downloads the new APK and opens the installer.
class AppUpdater {
  static const _bucket = 'app-releases';
  static bool _busy = false;
  static BuildContext? _context;
  static _ResumeWatcher? _watcher;

  /// Installed version, e.g. "1.0.57" — shown in Settings
  static Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Called by the dashboards each time they open. Checks now, and again whenever
  /// the app is brought back after being in the background for 5 minutes or more.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb) return; // the website is always the latest version
    _context = context;
    if (_watcher == null) {
      _watcher = _ResumeWatcher();
      WidgetsBinding.instance.addObserver(_watcher!);
    }
    await _check();
  }

  static Future<void> _check() async {
    final context = _context;
    if (kIsWeb || _busy || context == null || !context.mounted || !Platform.isAndroid) return;
    _busy = true;
    try {
      final storage = Supabase.instance.client.storage.from(_bucket);
      final infoUrl = storage.getPublicUrl('latest.json');
      final res = await Dio().get<String>(
        '$infoUrl?t=${DateTime.now().millisecondsSinceEpoch}',
        options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 15)),
      );
      final info = jsonDecode(res.data ?? '{}') as Map<String, dynamic>;
      final latestBuild = int.tryParse('${info['build']}') ?? 0;
      final apkName = info['apk'] as String?;
      final pkg = await PackageInfo.fromPlatform();
      final mine = int.tryParse(pkg.buildNumber) ?? 0;
      if (apkName == null || latestBuild <= mine) return;
      if (!context.mounted) return;
      final apkUrl = storage.getPublicUrl(apkName);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(
          apkUrl: apkUrl,
          build: latestBuild,
          installed: pkg.version,
          latest: (info['version'] as String?) ?? '1.0.$latestBuild',
        ),
      );
    } catch (_) {
      // No internet / nothing published yet — try again next time the app opens
    } finally {
      _busy = false;
    }
  }
}

class _ResumeWatcher with WidgetsBindingObserver {
  DateTime? _wentAway;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wentAway = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _wentAway;
      _wentAway = null;
      if (away != null && DateTime.now().difference(away) >= const Duration(minutes: 5)) {
        AppUpdater._check();
      }
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final String apkUrl;
  final int build;
  final String installed;
  final String latest;
  const _UpdateDialog({required this.apkUrl, required this.build, required this.installed, required this.latest});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress; // null = not started
  String? _error;

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/chakka-saarthi-${widget.build}.apk';
      await Dio().download(widget.apkUrl, path, onReceiveProgress: (got, total) {
        if (total > 0 && mounted) setState(() => _progress = got / total);
      });
      final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        // Usually: Android needs "Install unknown apps" allowed for Chakka Saarthi
        if (mounted) {
          setState(() {
            _progress = null;
            _error = 'Allow "Install unknown apps" for Chakka Saarthi in phone settings, then tap Update again.';
          });
        }
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'Download failed. Check internet and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null;
    return AlertDialog(
      title: const Text('New version available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(downloading
              ? 'Downloading… ${(_progress! * 100).toStringAsFixed(0)}%'
              : 'A new version of Chakka Saarthi is ready. Tap Update to install it.\n\n'
                  'Your version: ${widget.installed}\nNew version: ${widget.latest}'),
          if (downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress, color: AppColors.brandYellow),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
          ],
        ],
      ),
      actions: downloading
          ? null
          : [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')),
              ElevatedButton(
                onPressed: _download,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandYellow,
                  foregroundColor: AppColors.ink,
                ),
                child: const Text('Update'),
              ),
            ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/utils/app_updater.dart';

/// "App version 1.0.57" line at the bottom of Settings
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AppUpdater.installedVersion(),
      builder: (context, snap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          snap.hasData ? 'App version ${snap.data}' : '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

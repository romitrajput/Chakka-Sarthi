import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF1B4F72);
  static const Color primaryMid = Color(0xFF2874A6);
  static const Color accentOrange = Color(0xFFE67E22);
  static const Color successGreen = Color(0xFF27AE60);
  static const Color errorRed = Color(0xFFE74C3C);
  static const Color warningYellow = Color(0xFFF39C12);
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // Gradient definitions for Dashboard Cards
  static const List<Color> createTripGradient = [Color(0xFF1B4F72), Color(0xFF2874A6)];
  static const List<Color> inTransitGradient = [Color(0xFFF39C12), Color(0xFFE67E22)];
  static const List<Color> completedGradient = [Color(0xFF27AE60), Color(0xFF1E8449)];
  static const List<Color> availableGradient = [Color(0xFF2874A6), Color(0xFF1B4F72)];
  static const List<Color> maintenanceGradient = [Color(0xFFE74C3C), Color(0xFFC0392B)];
  static const List<Color> reportsGradient = [Color(0xFF8E44AD), Color(0xFF6C3483)];

  // Status Chip Backgrounds
  static const Color availableBg = Color(0xFFE8F8F0);
  static const Color inTransitBg = Color(0xFFFEF9E7);
  static const Color maintenanceBg = Color(0xFFFEF0E7);
  static const Color completedBg = Color(0xFFEBF5FB);
  static const Color assignedBg = Color(0xFFF0F3FA);
  static const Color cancelledBg = Color(0xFFFDEDEC);
}

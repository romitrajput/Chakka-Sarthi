import 'package:flutter/material.dart';

/// Chakka Saarthi theme — colours taken from the logo / brand kit.
/// Names are kept from the old theme so every screen picks up the new look.
class AppColors {
  // Brand
  static const Color ink = Color(0xFF14161F); // top bars, headings
  static const Color roadGrey = Color(0xFF2A2E3B); // dark cards, secondary
  static const Color brandYellow = Color(0xFFFFD23F); // the main action on a screen
  static const Color onBrandYellow = ink; // text/icons on yellow
  static const Color mist = Color(0xFFF4F4F0); // screen background
  static const Color goGreen = Color(0xFF1FA971); // success fills, charts
  static const Color workshopOrange = Color(0xFFE8590C); // maintenance fills, charts

  // Core roles (old names, new values)
  static const Color primaryDark = ink;
  static const Color primaryMid = roadGrey;
  static const Color accentOrange = Color(0xFFB45309); // amber, readable on white and under white text
  static const Color successGreen = Color(0xFF137A4F); // readable green
  static const Color errorRed = Color(0xFFC53030);
  static const Color warningYellow = Color(0xFF8A6A00); // dark gold, readable as text
  static const Color background = mist;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF5B6070);
  static const Color divider = Color(0xFFE4E4DE);

  // Gradients (kept for older widgets)
  static const List<Color> createTripGradient = [ink, roadGrey];
  static const List<Color> inTransitGradient = [Color(0xFFFFD23F), Color(0xFFF2B705)];
  static const List<Color> completedGradient = [roadGrey, ink];
  static const List<Color> availableGradient = [goGreen, successGreen];
  static const List<Color> maintenanceGradient = [workshopOrange, Color(0xFFA33A00)];
  static const List<Color> reportsGradient = [roadGrey, ink];

  // Status chip backgrounds
  static const Color availableBg = Color(0xFFE3F5EC);
  static const Color inTransitBg = Color(0xFFFFF3C4);
  static const Color maintenanceBg = Color(0xFFFDEBDD);
  static const Color completedBg = Color(0xFFE9EAEE);
  static const Color assignedBg = Color(0xFFF4F4F0);
  static const Color cancelledBg = Color(0xFFFDE8E8);
}

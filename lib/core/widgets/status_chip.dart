import 'package:flutter/material.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'available':
        backgroundColor = AppColors.availableBg;
        textColor = AppColors.successGreen;
        label = 'AVAILABLE';
        break;
      case 'in_transit':
        backgroundColor = AppColors.inTransitBg;
        textColor = AppColors.warningYellow;
        label = 'IN TRANSIT';
        break;
      case 'maintenance':
        backgroundColor = AppColors.maintenanceBg;
        textColor = AppColors.accentOrange;
        label = 'MAINTENANCE';
        break;
      case 'completed':
        backgroundColor = AppColors.completedBg;
        textColor = AppColors.primaryMid;
        label = 'COMPLETED';
        break;
      case 'assigned':
        backgroundColor = AppColors.assignedBg;
        textColor = AppColors.primaryDark;
        label = 'ASSIGNED';
        break;
      case 'cancelled':
        backgroundColor = AppColors.cancelledBg;
        textColor = AppColors.errorRed;
        label = 'CANCELLED';
        break;
      default:
        backgroundColor = AppColors.divider;
        textColor = AppColors.textSecondary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

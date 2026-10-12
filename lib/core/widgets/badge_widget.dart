import 'package:flutter/material.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';

class BadgeWidget extends StatelessWidget {
  final int count;
  final double size;
  final double fontSize;
  final Color? color;
  final Color? textColor;

  const BadgeWidget({
    super.key,
    required this.count,
    this.size = 22,
    this.fontSize = 12,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: textColor ?? AppColors.primaryDark,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

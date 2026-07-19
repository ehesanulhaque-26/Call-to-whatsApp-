import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

enum ChipStatus { active, inactive, warning, error }

class StatusChip extends StatelessWidget {
  const StatusChip({required super.key, required this.label, required this.status, this.icon});

  final String label;
  final ChipStatus status;
  final IconData? icon;

  Color _getBackgroundColor() {
    switch (status) {
      case ChipStatus.active: return AppColors.success.withOpacity(0.1);
      case ChipStatus.inactive: return AppColors.textTertiary.withOpacity(0.1);
      case ChipStatus.warning: return AppColors.warning.withOpacity(0.1);
      case ChipStatus.error: return AppColors.error.withOpacity(0.1);
    }
  }

  Color _getTextColor() {
    switch (status) {
      case ChipStatus.active: return AppColors.success;
      case ChipStatus.inactive: return AppColors.textSecondary;
      case ChipStatus.warning: return AppColors.warning;
      case ChipStatus.error: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: _getBackgroundColor(), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: _getTextColor()), const SizedBox(width: AppSpacing.xs)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _getTextColor())),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

enum SessionStatus { connected, disconnected, pending, error }

class SessionCard extends StatelessWidget {
  const SessionCard({
    required super.key,
    required this.name,
    required this.phone,
    required this.status,
    this.onConnect,
    this.onDisconnect,
    this.onDelete,
    this.onTap,
  });

  final String name;
  final String phone;
  final SessionStatus status;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  Color _getStatusColor() {
    switch (status) {
      case SessionStatus.connected:
        return AppColors.success;
      case SessionStatus.disconnected:
        return AppColors.textSecondary;
      case SessionStatus.pending:
        return AppColors.warning;
      case SessionStatus.error:
        return AppColors.error;
    }
  }

  String _getStatusText() {
    switch (status) {
      case SessionStatus.connected:
        return 'Connected';
      case SessionStatus.disconnected:
        return 'Disconnected';
      case SessionStatus.pending:
        return 'Pending';
      case SessionStatus.error:
        return 'Error';
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case SessionStatus.connected:
        return Icons.check_circle;
      case SessionStatus.disconnected:
        return Icons.cancel_outlined;
      case SessionStatus.pending:
        return Icons.pending_outlined;
      case SessionStatus.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(Icons.smartphone, color: statusColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(), size: 14, color: statusColor),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _getStatusText(),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

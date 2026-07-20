import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

/// User notifications screen with mobile-first design
class UserNotificationsScreen extends ConsumerWidget {
  const UserNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications cleared')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
        },
        child: _buildNotificationsList(context),
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
    final notifications = [
      {
        'title': 'Session Connected',
        'body': 'Your WhatsApp session has been connected successfully.',
        'time': '2 min ago',
        'type': 'success',
      },
      {
        'title': 'Contacts Synced',
        'body': '150 contacts have been imported from your WhatsApp.',
        'time': '1 hour ago',
        'type': 'info',
      },
      {
        'title': 'Campaign Completed',
        'body': 'Your promotional campaign has been sent to 50 contacts.',
        'time': 'Yesterday',
        'type': 'campaign',
      },
    ];

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 64,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You\'re all caught up!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationCard(notification: notification);
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final Map<String, String> notification;

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (notification['type']) {
      case 'success':
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case 'error':
        color = AppColors.error;
        icon = Icons.error;
        break;
      case 'campaign':
        color = AppColors.primary;
        icon = Icons.campaign;
        break;
      default:
        color = AppColors.info;
        icon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? '',
                    style: AppTypography.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body'] ?? '',
                    style: AppTypography.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    notification['time'] ?? '',
                    style: AppTypography.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

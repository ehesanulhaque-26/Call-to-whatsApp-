import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          _buildBroadcastButton(),
          Expanded(child: _buildNotificationList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search notifications...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              borderSide: BorderSide.none,),
          filled: true,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildBroadcastButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showBroadcastDialog(context),
          icon: const Icon(Icons.campaign),
          label: const Text('Broadcast Notification'),
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    final notifications = [
      {
        'title': 'Welcome',
        'body': 'Welcome to the platform!',
        'type': 'info',
        'read': false,
        'time': 'Just now',
      },
      {
        'title': 'Update',
        'body': 'System update completed',
        'type': 'success',
        'read': true,
        'time': '2 hours ago',
      },
      {
        'title': 'Alert',
        'body': 'High usage detected',
        'type': 'warning',
        'read': false,
        'time': '1 day ago',
      },
    ];

    final filteredNotifications = notifications.where((n) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return (n['title'] as String).toLowerCase().contains(query) ||
            (n['body'] as String).toLowerCase().contains(query);
      }
      return true;
    }).toList();

    if (filteredNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off_outlined,
                size: 64, color: AppColors.textTertiary,),
            const SizedBox(height: AppSpacing.md),
            Text('No notifications',
                style: AppTypography.titleMedium
                    .copyWith(color: AppColors.textSecondary),),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => HapticFeedback.mediumImpact(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          return _NotificationCard(
            notification: notification,
            onTap: () => _markAsRead(notification),
          );
        },
      ),
    );
  }

  void _markAsRead(Map<String, Object> notification) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${notification['title']} marked as read')),);
  }

  void _showBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast Notification'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder(),),
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              decoration: InputDecoration(
                  labelText: 'Message', border: OutlineInputBorder(),),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification broadcasted')),);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final Map<String, Object> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification['read'] == 'true';
    Color color;

    switch (notification['type']) {
      case 'success':
        color = AppColors.success;
        break;
      case 'warning':
        color = AppColors.warning;
        break;
      case 'error':
        color = AppColors.error;
        break;
      default:
        color = AppColors.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                child: Icon(Icons.notifications, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] as String,
                            style: AppTypography.titleSmall
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] as String,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notification['time'] as String,
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

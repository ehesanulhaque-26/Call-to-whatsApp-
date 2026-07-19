import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../whatsapp/presentation/providers/whatsapp_provider.dart';
import '../../../whatsapp/data/models/whatsapp_connection.dart';

/// Home screen - main app shell
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenWA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.name ?? 'User',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      authState.email ?? '',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAdmin ? 'Admin' : 'User',
                        style: AppTypography.labelSmall.copyWith(
                          color: isAdmin
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(
                        Icons.chat_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${authState.name ?? 'User'}!',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your OpenWA dashboard is ready.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Quick stats (Phase 2 placeholder)
            Text(
              'Quick Stats',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.chat_outlined,
                    label: 'Sessions',
                    value: '0',
                    color: AppColors.info,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatCard(
                    icon: Icons.people_outline,
                    label: 'Contacts',
                    value: '0',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.send_outlined,
                    label: 'Messages',
                    value: '0',
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatCard(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Automations',
                    value: '0',
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // WhatsApp Connection Status
            Consumer(
              builder: (context, ref, _) {
                final whatsAppState = ref.watch(whatsAppProvider);
                final connection = whatsAppState.connection;
                final isConnected = connection?.state == WhatsAppConnectionState.connected;
                final isLoading = whatsAppState.isLoading;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Status',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: InkWell(
                        onTap: () => context.go(AppRoutes.whatsApp),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isConnected
                                      ? AppColors.success.withOpacity(0.1)
                                      : AppColors.textTertiary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Icon(
                                  isConnected ? Icons.check_circle : Icons.qr_code,
                                  color: isConnected ? AppColors.success : AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isConnected
                                          ? connection?.name ?? 'WhatsApp Connected'
                                          : 'Not Connected',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isConnected
                                          ? connection?.phone ?? 'Connected'
                                          : 'Tap to connect your WhatsApp',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isConnected) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'Connected',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.go(AppRoutes.whatsApp),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.xs,
                                    ),
                                  ),
                                  child: Text(isLoading ? 'Loading...' : 'Connect'),
                                ),
                              ],
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Connection Activity
                    if (connection?.lastConnected != null)
                      Card(
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.history,
                              color: AppColors.info,
                            ),
                          ),
                          title: const Text('Last Connected'),
                          subtitle: Text(
                            _formatLastConnected(connection!.lastConnected!),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            // OpenWA Server Status
            Text(
              'System Status',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Consumer(
              builder: (context, ref, _) {
                final whatsAppState = ref.watch(whatsAppProvider);
                final isHealthy = whatsAppState.openWAHealthy;

                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isHealthy
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        isHealthy ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                        color: isHealthy ? AppColors.success : AppColors.error,
                      ),
                    ),
                    title: const Text('OpenWA Server'),
                    subtitle: Text(
                      isHealthy ? 'Operational' : 'Unavailable',
                      style: AppTypography.bodySmall.copyWith(
                        color: isHealthy ? AppColors.success : AppColors.error,
                      ),
                    ),
                    trailing: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isHealthy ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            // Quick Actions
            Text(
              'Quick Actions',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _FeatureCard(
              icon: Icons.chat_bubble,
              title: 'WhatsApp Connection',
              description: 'Manage your WhatsApp connection',
              onTap: () => context.go(AppRoutes.whatsApp),
            ),
            const SizedBox(height: AppSpacing.sm),
            _FeatureCard(
              icon: Icons.auto_awesome,
              title: 'Automations',
              description: 'Create automated message workflows',
              isComing: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FeatureCard(
              icon: Icons.campaign,
              title: 'Campaigns',
              description: 'Send bulk messages to contacts',
              isComing: true,
            ),
            Text(
              'Coming Soon',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _FeatureCard(
              icon: Icons.auto_awesome,
              title: 'Automations',
              description: 'Create automated message workflows',
              isComing: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _FeatureCard(
              icon: Icons.campaign,
              title: 'Campaigns',
              description: 'Send bulk messages to contacts',
              isComing: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _FeatureCard(
              icon: Icons.analytics,
              title: 'Analytics',
              description: 'Track your message performance',
              isComing: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isComing = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isComing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.textTertiary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            icon,
            color: AppColors.textTertiary,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: isComing
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Soon',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            : onTap != null
                ? const Icon(Icons.chevron_right, color: AppColors.textTertiary)
                : null,
      ),
    );
  }
}

/// Format last connected time
String _formatLastConnected(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
  } else {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

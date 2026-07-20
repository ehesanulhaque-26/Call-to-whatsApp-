import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../whatsapp/presentation/providers/whatsapp_provider.dart';
import '../../../whatsapp/data/models/whatsapp_connection.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whatsAppState = ref.watch(whatsAppProvider);
    final connection = whatsAppState.connection;
    final isConnected = connection?.state == WhatsAppConnectionState.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: 'Connected Device',
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    isConnected ? Icons.check_circle : Icons.phone_android,
                    color: isConnected
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                ),
                title: const Text('WhatsApp'),
                subtitle: Text(
                  isConnected
                      ? (connection?.phone ?? 'Connected')
                      : 'Not connected',
                  style: TextStyle(
                    color: isConnected
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Security'),
                onTap: () {},
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'System Status',
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: whatsAppState.isConnected
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    whatsAppState.isConnected
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color: whatsAppState.isConnected
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                title: const Text('Backend Status'),
                subtitle: Text(
                  whatsAppState.isConnected ? 'Operational' : 'Unavailable',
                  style: TextStyle(
                    color: whatsAppState.isConnected
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: whatsAppState.isConnected
                        ? AppColors.success
                        : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.smartphone, color: AppColors.info),
                ),
                title: const Text('OpenWA Status'),
                subtitle: Text(
                  isConnected ? 'Connected' : 'Not connected',
                  style: TextStyle(
                    color: isConnected
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.success
                        : AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'Preferences',
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                onTap: () {},
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                onTap: () {},
              ),
              const ListTile(
                leading: Icon(Icons.code),
                title: Text('App Version'),
                subtitle: Text('1.0.0'),
              ),
            ],
          ),
          _buildSection(
            context,
            title: '',
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(children: children),
        ),
      ],
    );
  }
}

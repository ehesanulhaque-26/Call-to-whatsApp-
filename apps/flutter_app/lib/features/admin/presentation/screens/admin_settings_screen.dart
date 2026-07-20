import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsSection(
              title: 'Subscription Plans',
              children: [
                _SettingsTile(
                    icon: Icons.attach_money,
                    title: 'Monthly Plan',
                    subtitle: '\$19.99/month',
                    onTap: () => _editPlan(context, 'monthly'),),
                _SettingsTile(
                    icon: Icons.calendar_today,
                    title: 'Yearly Plan',
                    subtitle: '\$149.99/year',
                    onTap: () => _editPlan(context, 'yearly'),),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsSection(
              title: 'Branding',
              children: [
                _SettingsTile(
                    icon: Icons.apps,
                    title: 'App Name',
                    subtitle: 'OpenWA SaaS',
                    onTap: () => _editBranding(context),),
                _SettingsTile(
                    icon: Icons.color_lens,
                    title: 'Primary Color',
                    subtitle: '#2196F3',
                    onTap: () => _editColor(context),),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsSection(
              title: 'System',
              children: [
                _SettingsTile(
                    icon: Icons.build,
                    title: 'Maintenance Mode',
                    subtitle: 'Off',
                    trailing: Switch(value: false, onChanged: (value) {}),),
                _SettingsTile(
                    icon: Icons.notifications,
                    title: 'Email Notifications',
                    subtitle: 'Enabled',
                    trailing: Switch(value: true, onChanged: (value) {}),),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsSection(
              title: 'General',
              children: [
                _SettingsTile(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () => _changeLanguage(context),),
                _SettingsTile(
                    icon: Icons.schedule,
                    title: 'Timezone',
                    subtitle: 'UTC',
                    onTap: () => _changeTimezone(context),),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editPlan(BuildContext context, String plan) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Edit $plan plan')));
  }

  void _editBranding(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Edit branding')));
  }

  void _editColor(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Edit primary color')));
  }

  void _changeLanguage(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Change language')));
  }

  void _changeTimezone(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Change timezone')));
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTypography.titleMedium
                .copyWith(fontWeight: FontWeight.bold),),
        const SizedBox(height: AppSpacing.sm),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTypography.bodyMedium),
      subtitle: Text(subtitle,
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.textSecondary),),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

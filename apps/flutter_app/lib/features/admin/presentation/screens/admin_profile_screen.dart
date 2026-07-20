import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/data/models/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _ProfileHeader(authState: authState),
            const SizedBox(height: AppSpacing.lg),
            _MenuSection(
              title: 'Account',
              children: [
                _MenuItem(
                    icon: Icons.person,
                    title: 'Edit Profile',
                    onTap: () => _editProfile(context),),
                _MenuItem(
                    icon: Icons.lock,
                    title: 'Change Password',
                    onTap: () => _changePassword(context),),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _MenuSection(
              title: 'Preferences',
              children: [
                _MenuItem(
                    icon: Icons.palette,
                    title: 'Theme',
                    subtitle: 'System',
                    onTap: () => _changeTheme(context),),
                _MenuItem(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () => _changeLanguage(context),),
                _MenuItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    onTap: () => _manageNotifications(context),),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _MenuSection(
              title: 'About',
              children: [
                _MenuItem(
                    icon: Icons.info,
                    title: 'About',
                    subtitle: 'Version 1.0.0',
                    onTap: () => _showAbout(context),),
                _MenuItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () => _showHelp(context),),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Logout',
                    style: TextStyle(color: AppColors.error),),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _editProfile(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _EditProfileSheet(),
    );
  }

  void _changePassword(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ChangePasswordSheet(),
    );
  }

  void _changeTheme(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Change theme')));
  }

  void _changeLanguage(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Change language')));
  }

  void _manageNotifications(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Manage notifications')));
  }

  void _showAbout(BuildContext context) {
    HapticFeedback.lightImpact();
    showAboutDialog(
      context: context,
      applicationName: 'OpenWA SaaS',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.admin_panel_settings, color: Colors.white),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Help & Support')));
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  (authState.name?.isNotEmpty == true
                          ? authState.name![0]
                          : 'A')
                      .toUpperCase(),
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: AppColors.primary,),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            authState.name ?? 'Admin',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,),
          ),
          Text(
            authState.email ?? 'admin@example.com',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Administrator',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500,),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.children});

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

class _MenuItem extends StatelessWidget {
  const _MenuItem(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap,});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

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
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),)
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

class _EditProfileSheet extends StatelessWidget {
  const _EditProfileSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Edit Profile',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),),
            const SizedBox(height: AppSpacing.lg),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Name', prefixIcon: Icon(Icons.person),),),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Save Changes'),),
            ),
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + AppSpacing.md,),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatelessWidget {
  const _ChangePasswordSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Change Password',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),),
            const SizedBox(height: AppSpacing.lg),
            const TextField(
                obscureText: true,
                decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock),),),
            const SizedBox(height: AppSpacing.md),
            const TextField(
                obscureText: true,
                decoration: InputDecoration(
                    labelText: 'New Password', prefixIcon: Icon(Icons.lock),),),
            const SizedBox(height: AppSpacing.md),
            const TextField(
                obscureText: true,
                decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock),),),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Update Password'),),
            ),
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + AppSpacing.md,),
          ],
        ),
      ),
    );
  }
}

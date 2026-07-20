import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  static const List<_NavItem> _navItems = [
    _NavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
        route: AppRoutes.admin,),
    _NavItem(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Users',
        route: AppRoutes.adminUsers,),
    _NavItem(
        icon: Icons.subscriptions_outlined,
        selectedIcon: Icons.subscriptions,
        label: 'Subscriptions',
        route: AppRoutes.adminSubscriptions,),
    _NavItem(
        icon: Icons.phone_android_outlined,
        selectedIcon: Icons.phone_android,
        label: 'WhatsApp Sessions',
        route: AppRoutes.adminSessions,),
    _NavItem(
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: 'Notifications',
        route: AppRoutes.adminNotifications,),
    _NavItem(
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
        label: 'Activity Logs',
        route: AppRoutes.adminLogs,),
    _NavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'System Settings',
        route: AppRoutes.adminSettings,),
    _NavItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile',
        route: AppRoutes.adminProfile,),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWideScreen = MediaQuery.of(context).size.width >= 800;
    final isDesktop = MediaQuery.of(context).size.width >= 1200;

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            _AdminNavigationRail(currentPath: currentPath, extended: isDesktop),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(currentPath)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _AdminDrawer(currentPath: currentPath),
      body: child,
    );
  }

  String _getTitle(String path) {
    for (final item in _navItems) {
      if (path == item.route || path.startsWith('${item.route}/')) {
        return item.label;
      }
    }
    return 'Admin';
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}

class _AdminNavigationRail extends StatelessWidget {
  const _AdminNavigationRail(
      {required this.currentPath, required this.extended,});

  final String currentPath;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(currentPath);

    return NavigationRail(
      extended: extended,
      minExtendedWidth: 220,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => _navigate(context, index),
      leading: _buildHeader(context, extended),
      destinations: AdminShell._navItems.map((item) {
        return NavigationRailDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: Text(item.label),
        );
      }).toList(),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildLogoutButton(context),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool extended) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.admin_panel_settings,
                color: Colors.white, size: 28,),
          ),
          if (extended) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Admin Panel',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return extended
        ? ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title:
                const Text('Logout', style: TextStyle(color: AppColors.error)),
            onTap: () => _handleLogout(context),
          )
        : IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: () => _handleLogout(context),
          );
  }

  int _getSelectedIndex(String path) {
    for (int i = 0; i < AdminShell._navItems.length; i++) {
      if (path == AdminShell._navItems[i].route) return i;
    }
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    context.go(AdminShell._navItems[index].route);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.heavyImpact();
      context.go(AppRoutes.login);
    }
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 32,),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'System Administration',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: AdminShell._navItems.length,
                itemBuilder: (context, index) {
                  final item = AdminShell._navItems[index];
                  final isSelected = currentPath == item.route;

                  return ListTile(
                    leading: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? AppColors.primary : null,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withOpacity(0.1),
                    onTap: () {
                      Navigator.pop(context);
                      HapticFeedback.selectionClick();
                      context.go(item.route);
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Logout',
                  style: TextStyle(color: AppColors.error),),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  HapticFeedback.heavyImpact();
                  context.go(AppRoutes.login);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

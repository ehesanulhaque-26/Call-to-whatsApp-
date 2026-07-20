import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWideScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSpacing.lg),
              _buildStatsGrid(context, isWideScreen),
              const SizedBox(height: AppSpacing.lg),
              if (isWideScreen)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildRecentUsers(context)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildQuickActions(context)),
                  ],
                )
              else ...[
                _buildRecentUsers(context),
                const SizedBox(height: AppSpacing.md),
                _buildQuickActions(context),
              ],
              const SizedBox(height: AppSpacing.lg),
              _buildRecentActivity(context),
              const SizedBox(height: AppSpacing.lg),
              _buildSystemHealth(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'System overview and management',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isWideScreen) {
    final stats = [
      const _StatData(icon: Icons.people, label: 'Total Users', value: '0', color: AppColors.primary, trend: '+0'),
      const _StatData(icon: Icons.people_alt, label: 'Active Users', value: '0', color: AppColors.success, trend: '+0'),
      const _StatData(icon: Icons.phone_android, label: 'WhatsApp Sessions', value: '0', color: AppColors.info, trend: '+0'),
      const _StatData(icon: Icons.subscriptions, label: 'Active Subscriptions', value: '0', color: AppColors.warning, trend: '+0'),
      const _StatData(icon: Icons.calendar_view_month, label: 'Monthly Subscribers', value: '0', color: AppColors.primary, trend: '+0'),
      const _StatData(icon: Icons.calendar_today, label: 'Yearly Subscribers', value: '0', color: AppColors.secondary, trend: '+0'),
      const _StatData(icon: Icons.attach_money, label: 'Revenue', value: '\$0', color: AppColors.success, trend: '+0'),
      const _StatData(icon: Icons.health_and_safety, label: 'System Status', value: 'Healthy', color: AppColors.success, trend: ''),
    ];

    if (isWideScreen) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.5,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) => _StatCard(data: stats[index]),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _StatCard(data: stats[index]),
    );
  }

  Widget _buildRecentUsers(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Users', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => context.go(AppRoutes.adminUsers), child: const Text('View All')),
              ],
            ),
            const Divider(),
            const _UserListItem(name: 'No users yet', email: 'users will appear here', status: 'info'),
            const _UserListItem(name: 'John Doe', email: 'john@example.com', status: 'active'),
            const _UserListItem(name: 'Jane Smith', email: 'jane@example.com', status: 'active'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _QuickActionButton(
              icon: Icons.person_add,
              label: 'Add User',
              onTap: () {},
            ),
            _QuickActionButton(
              icon: Icons.campaign,
              label: 'Broadcast',
              onTap: () {},
            ),
            _QuickActionButton(
              icon: Icons.settings,
              label: 'Settings',
              onTap: () => context.go(AppRoutes.adminSettings),
            ),
            _QuickActionButton(
              icon: Icons.history,
              label: 'View Logs',
              onTap: () => context.go(AppRoutes.adminLogs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => context.go(AppRoutes.adminLogs), child: const Text('View All')),
              ],
            ),
            const Divider(),
            const _ActivityItem(icon: Icons.login, title: 'Admin login', time: 'Just now', color: AppColors.success),
            const _ActivityItem(icon: Icons.person_add, title: 'New user registered', time: '2 hours ago', color: AppColors.info),
            const _ActivityItem(icon: Icons.subscriptions, title: 'Subscription created', time: '5 hours ago', color: AppColors.primary),
            const _ActivityItem(icon: Icons.phone_android, title: 'WhatsApp session connected', time: '1 day ago', color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealth(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Health', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            const _HealthItem(label: 'Backend API', status: 'Operational', color: AppColors.success),
            const _HealthItem(label: 'Database', status: 'Operational', color: AppColors.success),
            const _HealthItem(label: 'OpenWA Service', status: 'Unknown', color: AppColors.warning),
            const _HealthItem(label: 'Supabase', status: 'Operational', color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.trend,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String trend;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: data.color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(data.icon, color: data.color, size: 20),
                ),
                const Spacer(),
                if (data.trend.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      data.trend,
                      style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              data.value,
              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              data.label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  const _UserListItem({required this.name, required this.email, required this.status});

  final String name;
  final String email;
  final String status;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
      ),
      title: Text(name, style: AppTypography.bodyMedium),
      subtitle: Text(email, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: status == 'active' ? AppColors.success.withOpacity(0.1) : AppColors.textTertiary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          status == 'active' ? 'Active' : 'Info',
          style: TextStyle(color: status == 'active' ? AppColors.success : AppColors.textTertiary, fontSize: 12),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: AppTypography.bodyMedium),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.icon, required this.title, required this.time, required this.color});

  final IconData icon;
  final String title;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: AppTypography.bodyMedium),
      trailing: Text(time, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
    );
  }
}

class _HealthItem extends StatelessWidget {
  const _HealthItem({required this.label, required this.status, required this.color});

  final String label;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTypography.bodyMedium)),
          Text(status, style: AppTypography.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('System Overview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.people, label: 'Users', value: '0', color: AppColors.primary)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _StatCard(icon: Icons.subscriptions, label: 'Subscriptions', value: '0', color: AppColors.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.phone_android, label: 'Sessions', value: '0', color: AppColors.info)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _StatCard(icon: Icons.auto_awesome, label: 'Automations', value: '0', color: AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
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
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

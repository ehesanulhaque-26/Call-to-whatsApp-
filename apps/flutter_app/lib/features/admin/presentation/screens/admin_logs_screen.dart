import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all';

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
          _buildFilterChips(),
          Expanded(child: _buildLogList()),
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
          hintText: 'Search logs...',
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

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          _FilterChip(
              label: 'All',
              value: 'all',
              selected: _typeFilter == 'all',
              onSelected: () => setState(() => _typeFilter = 'all'),),
          _FilterChip(
              label: 'Login',
              value: 'login',
              selected: _typeFilter == 'login',
              onSelected: () => setState(() => _typeFilter = 'login'),),
          _FilterChip(
              label: 'Logout',
              value: 'logout',
              selected: _typeFilter == 'logout',
              onSelected: () => setState(() => _typeFilter = 'logout'),),
          _FilterChip(
              label: 'User',
              value: 'user',
              selected: _typeFilter == 'user',
              onSelected: () => setState(() => _typeFilter = 'user'),),
          _FilterChip(
              label: 'Admin',
              value: 'admin',
              selected: _typeFilter == 'admin',
              onSelected: () => setState(() => _typeFilter = 'admin'),),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    final logs = [
      {
        'action': 'Login',
        'user': 'Admin',
        'details': 'Admin logged in',
        'type': 'login',
        'time': 'Just now',
      },
      {
        'action': 'User Created',
        'user': 'Admin',
        'details': 'New user created: John',
        'type': 'admin',
        'time': '2 hours ago',
      },
      {
        'action': 'Logout',
        'user': 'John',
        'details': 'User logged out',
        'type': 'logout',
        'time': '5 hours ago',
      },
      {
        'action': 'Login',
        'user': 'John',
        'details': 'User logged in',
        'type': 'login',
        'time': '6 hours ago',
      },
    ];

    final filteredLogs = logs.where((l) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!(l['action'] as String).toLowerCase().contains(query) &&
            !(l['user'] as String).toLowerCase().contains(query) &&
            !(l['details'] as String).toLowerCase().contains(query)) {
          return false;
        }
      }
      if (_typeFilter != 'all' && l['type'] != _typeFilter) return false;
      return true;
    }).toList();

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_outlined,
                size: 64, color: AppColors.textTertiary,),
            const SizedBox(height: AppSpacing.md),
            Text('No logs found',
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
        itemCount: filteredLogs.length,
        itemBuilder: (context, index) {
          final log = filteredLogs[index];
          return _LogCard(log: log);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onSelected,});
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final Map<String, String> log;

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (log['type']) {
      case 'login':
        color = AppColors.success;
        icon = Icons.login;
        break;
      case 'logout':
        color = AppColors.warning;
        icon = Icons.logout;
        break;
      case 'admin':
        color = AppColors.primary;
        icon = Icons.admin_panel_settings;
        break;
      default:
        color = AppColors.info;
        icon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log['action'] as String,
                      style: AppTypography.titleSmall
                          .copyWith(fontWeight: FontWeight.bold),),
                  const SizedBox(height: 4),
                  Text(log['details'] as String,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.person,
                          size: 14, color: AppColors.textTertiary,),
                      const SizedBox(width: 4),
                      Text(log['user'] as String,
                          style: AppTypography.labelSmall
                              .copyWith(color: AppColors.textTertiary),),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.access_time,
                          size: 14, color: AppColors.textTertiary,),
                      const SizedBox(width: 4),
                      Text(log['time'] as String,
                          style: AppTypography.labelSmall
                              .copyWith(color: AppColors.textTertiary),),
                    ],
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

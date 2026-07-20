import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';

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
          _buildFilters(),
          Expanded(child: _buildUserList()),
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
          hintText: 'Search users...',
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _roleFilter,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Roles')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'user', child: Text('User')),
              ],
              onChanged: (value) => setState(() => _roleFilter = value!),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (value) => setState(() => _statusFilter = value!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final users = [
      {
        'name': 'John Doe',
        'email': 'john@example.com',
        'role': 'user',
        'status': 'active',
      },
      {
        'name': 'Jane Smith',
        'email': 'jane@example.com',
        'role': 'user',
        'status': 'active',
      },
      {
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': 'admin',
        'status': 'active',
      },
      {
        'name': 'Bob Wilson',
        'email': 'bob@example.com',
        'role': 'user',
        'status': 'inactive',
      },
    ];

    final filteredUsers = users.where((u) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!(u['name'] as String).toLowerCase().contains(query) &&
            !(u['email'] as String).toLowerCase().contains(query)) {
          return false;
        }
      }
      if (_roleFilter != 'all' && u['role'] != _roleFilter) return false;
      if (_statusFilter != 'all' && u['status'] != _statusFilter) return false;
      return true;
    }).toList();

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline,
                size: 64, color: AppColors.textTertiary,),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No users found',
              style: AppTypography.titleMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final user = filteredUsers[index];
          return _UserCard(
            user: user,
            onTap: () => _showUserDetails(context, user),
            onRoleChange: () => _showRoleDialog(context, user),
            onStatusChange: () => _toggleStatus(context, user),
            onDelete: () => _showDeleteDialog(context, user),
          );
        },
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, String> user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                (user['name'] as String)[0].toUpperCase(),
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(user['name'] as String,
                style: AppTypography.titleLarge
                    .copyWith(fontWeight: FontWeight.bold),),
            Text(user['email'] as String,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Role'),
              trailing: Text(user['role'] as String),
            ),
            ListTile(
              leading: const Icon(Icons.circle, size: 12),
              title: const Text('Status'),
              trailing: Text(user['status'] as String),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showRoleDialog(BuildContext context, Map<String, String> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Admin'),
              leading: Radio<String>(
                value: 'admin',
                groupValue: user['role'],
                onChanged: (value) {
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                },
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('User'),
              leading: Radio<String>(
                value: 'user',
                groupValue: user['role'],
                onChanged: (value) {
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                },
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus(BuildContext context, Map<String, String> user) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user['name']} status toggled')),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, String> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user['name']} deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onRoleChange,
    required this.onStatusChange,
    required this.onDelete,
  });

  final Map<String, String> user;
  final VoidCallback onTap;
  final VoidCallback onRoleChange;
  final VoidCallback onStatusChange;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    

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
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  (user['name'] as String)[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] as String,
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.bold),),
                    Text(user['email'] as String,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'role':
                      onRoleChange();
                      break;
                    case 'status':
                      onStatusChange();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'role',
                      child: ListTile(
                          leading: Icon(Icons.admin_panel_settings),
                          title: Text('Change Role'),),),
                  const PopupMenuItem(
                      value: 'status',
                      child: ListTile(
                          leading: Icon(Icons.toggle_on),
                          title: Text('Toggle Status'),),),
                  const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                          leading: Icon(Icons.delete, color: AppColors.error),
                          title: Text('Delete',
                              style: TextStyle(color: AppColors.error),),),),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

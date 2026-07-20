import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminSessionsScreen extends ConsumerStatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  ConsumerState<AdminSessionsScreen> createState() =>
      _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends ConsumerState<AdminSessionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
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
          _buildFilterChips(),
          Expanded(child: _buildSessionList()),
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
          hintText: 'Search sessions...',
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
              selected: _statusFilter == 'all',
              onSelected: () => setState(() => _statusFilter = 'all'),),
          _FilterChip(
              label: 'Connected',
              value: 'connected',
              selected: _statusFilter == 'connected',
              onSelected: () => setState(() => _statusFilter = 'connected'),),
          _FilterChip(
              label: 'Disconnected',
              value: 'disconnected',
              selected: _statusFilter == 'disconnected',
              onSelected: () => setState(() => _statusFilter = 'disconnected'),),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    final sessions = [
      {
        'name': 'John\'s Phone',
        'owner': 'John Doe',
        'phone': '+1234567890',
        'status': 'connected',
        'connectedTime': '2 hours',
      },
      {
        'name': 'Jane\'s Phone',
        'owner': 'Jane Smith',
        'phone': '+0987654321',
        'status': 'connected',
        'connectedTime': '1 day',
      },
      {
        'name': 'Bob\'s Phone',
        'owner': 'Bob Wilson',
        'phone': '+1122334455',
        'status': 'disconnected',
        'connectedTime': 'N/A',
      },
    ];

    final filteredSessions = sessions.where((s) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!(s['name'] as String).toLowerCase().contains(query) &&
            !(s['owner'] as String).toLowerCase().contains(query) &&
            !(s['phone'] as String).contains(query)) {
          return false;
        }
      }
      if (_statusFilter != 'all' && s['status'] != _statusFilter) return false;
      return true;
    }).toList();

    if (filteredSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android_outlined,
                size: 64, color: AppColors.textTertiary,),
            const SizedBox(height: AppSpacing.md),
            Text('No sessions found',
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
        itemCount: filteredSessions.length,
        itemBuilder: (context, index) {
          final session = filteredSessions[index];
          return _SessionCard(
            session: session,
            onTap: () => _showSessionDetails(context, session),
            onDisconnect: () => _disconnectSession(context, session),
            onDelete: () => _deleteSession(context, session),
          );
        },
      ),
    );
  }

  void _showSessionDetails(BuildContext context, Map<String, String> session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session Details',
                style: AppTypography.titleLarge
                    .copyWith(fontWeight: FontWeight.bold),),
            const Divider(),
            _DetailRow(label: 'Name', value: session['name'] as String),
            _DetailRow(label: 'Owner', value: session['owner'] as String),
            _DetailRow(label: 'Phone', value: session['phone'] as String),
            _DetailRow(label: 'Status', value: session['status'] as String),
            _DetailRow(
                label: 'Connected Time',
                value: session['connectedTime'] as String,),
          ],
        ),
      ),
    );
  }

  void _disconnectSession(BuildContext context, Map<String, String> session) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${session['name']} disconnected')),);
  }

  void _deleteSession(BuildContext context, Map<String, String> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete ${session['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${session['name']} deleted')),);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
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

class _SessionCard extends StatelessWidget {
  const _SessionCard(
      {required this.session,
      required this.onTap,
      required this.onDisconnect,
      required this.onDelete,});
  final Map<String, String> session;
  final VoidCallback onTap;
  final VoidCallback onDisconnect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isConnected = session['status'] == 'connected';

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (isConnected ? AppColors.success : AppColors.textTertiary)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.phone_android,
                    color: isConnected
                        ? AppColors.success
                        : AppColors.textTertiary,),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session['name'] as String,
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.bold),),
                    Text(session['owner'] as String,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),),
                    Text(session['phone'] as String,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary),),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isConnected
                              ? AppColors.success
                              : AppColors.textTertiary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                            color: isConnected
                                ? AppColors.success
                                : AppColors.textTertiary,
                            fontSize: 12,),),
                  ),
                  const SizedBox(height: 4),
                  Text(session['connectedTime'] as String,
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.textTertiary),),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'disconnect':
                      onDisconnect();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (isConnected)
                    const PopupMenuItem(
                        value: 'disconnect',
                        child: ListTile(
                            leading: Icon(Icons.link_off),
                            title: Text('Disconnect'),),),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),),
          Text(value,
              style: AppTypography.bodyMedium
                  .copyWith(fontWeight: FontWeight.w500),),
        ],
      ),
    );
  }
}

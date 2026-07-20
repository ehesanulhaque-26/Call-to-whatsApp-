import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all';

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
          Expanded(child: _buildSubscriptionList()),
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
          hintText: 'Search subscriptions...',
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
              selected: _filter == 'all',
              onSelected: () => setState(() => _filter = 'all'),),
          _FilterChip(
              label: 'Monthly',
              value: 'monthly',
              selected: _filter == 'monthly',
              onSelected: () => setState(() => _filter = 'monthly'),),
          _FilterChip(
              label: 'Yearly',
              value: 'yearly',
              selected: _filter == 'yearly',
              onSelected: () => setState(() => _filter = 'yearly'),),
          _FilterChip(
              label: 'Active',
              value: 'active',
              selected: _filter == 'active',
              onSelected: () => setState(() => _filter = 'active'),),
          _FilterChip(
              label: 'Expired',
              value: 'expired',
              selected: _filter == 'expired',
              onSelected: () => setState(() => _filter = 'expired'),),
        ],
      ),
    );
  }

  Widget _buildSubscriptionList() {
    final subscriptions = [
      {
        'user': 'John Doe',
        'email': 'john@example.com',
        'plan': 'Monthly',
        'status': 'active',
        'price': '\$19.99',
      },
      {
        'user': 'Jane Smith',
        'email': 'jane@example.com',
        'plan': 'Yearly',
        'status': 'active',
        'price': '\$149.99',
      },
      {
        'user': 'Bob Wilson',
        'email': 'bob@example.com',
        'plan': 'Monthly',
        'status': 'expired',
        'price': '\$19.99',
      },
    ];

    final filteredSubscriptions = subscriptions.where((s) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!(s['user'] as String).toLowerCase().contains(query) &&
            !(s['email'] as String).toLowerCase().contains(query)) {
          return false;
        }
      }
      if (_filter != 'all' && s['status'] != _filter && s['plan'] != _filter) {
        return false;
      }
      return true;
    }).toList();

    if (filteredSubscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.subscriptions_outlined,
                size: 64, color: AppColors.textTertiary,),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No subscriptions found',
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
        itemCount: filteredSubscriptions.length,
        itemBuilder: (context, index) {
          final subscription = filteredSubscriptions[index];
          return _SubscriptionCard(
            subscription: subscription,
            onTap: () => _showSubscriptionDetails(context, subscription),
            onActivate: () => _activateSubscription(context, subscription),
            onCancel: () => _cancelSubscription(context, subscription),
            onExtend: () => _extendSubscription(context, subscription),
          );
        },
      ),
    );
  }

  void _showSubscriptionDetails(
      BuildContext context, Map<String, String> subscription,) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription Details',
                style: AppTypography.titleLarge
                    .copyWith(fontWeight: FontWeight.bold),),
            const Divider(),
            _DetailRow(label: 'User', value: subscription['user'] as String),
            _DetailRow(label: 'Email', value: subscription['email'] as String),
            _DetailRow(label: 'Plan', value: subscription['plan'] as String),
            _DetailRow(label: 'Price', value: subscription['price'] as String),
            _DetailRow(
                label: 'Status', value: subscription['status'] as String,),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _activateSubscription(
      BuildContext context, Map<String, String> subscription,) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${subscription['user']} subscription activated')),
    );
  }

  void _cancelSubscription(
      BuildContext context, Map<String, String> subscription,) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${subscription['user']} subscription cancelled')),
    );
  }

  void _extendSubscription(
      BuildContext context, Map<String, String> subscription,) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${subscription['user']} subscription extended')),
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.onTap,
    required this.onActivate,
    required this.onCancel,
    required this.onExtend,
  });

  final Map<String, String> subscription;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onCancel;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final isActive = subscription['status'] == 'active';

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
                  color: (isActive ? AppColors.success : AppColors.error)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.subscriptions,
                  color: isActive ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subscription['user'] as String,
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.bold),),
                    Text(subscription['plan'] as String,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),),
                    Text(subscription['price'] as String,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.primary),),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.success : AppColors.error)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  isActive ? 'Active' : 'Expired',
                  style: TextStyle(
                      color: isActive ? AppColors.success : AppColors.error,
                      fontSize: 12,),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'activate':
                      onActivate();
                      break;
                    case 'cancel':
                      onCancel();
                      break;
                    case 'extend':
                      onExtend();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (!isActive)
                    const PopupMenuItem(
                        value: 'activate',
                        child: ListTile(
                            leading: Icon(Icons.check),
                            title: Text('Activate'),),),
                  if (isActive)
                    const PopupMenuItem(
                        value: 'cancel',
                        child: ListTile(
                            leading: Icon(Icons.cancel),
                            title: Text('Cancel'),),),
                  const PopupMenuItem(
                      value: 'extend',
                      child: ListTile(
                          leading: Icon(Icons.add), title: Text('Extend'),),),
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

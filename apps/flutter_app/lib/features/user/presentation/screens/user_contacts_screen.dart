import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';

/// User contacts screen with mobile-first design
class UserContactsScreen extends ConsumerStatefulWidget {
  const UserContactsScreen({super.key});

  @override
  ConsumerState<UserContactsScreen> createState() => _UserContactsScreenState();
}

class _UserContactsScreenState extends ConsumerState<UserContactsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
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
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Contacts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
              },
              child: _buildContactsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    // Sample contacts data
    final contacts = [
      {'name': 'John Doe', 'phone': '+1234567890', 'pushname': 'Johnny'},
      {'name': 'Jane Smith', 'phone': '+0987654321', 'pushname': 'Jane'},
      {'name': 'Bob Wilson', 'phone': '+1122334455', 'pushname': 'Bobby'},
    ];

    final filteredContacts = contacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return (c['name'] as String).toLowerCase().contains(query) ||
          (c['phone'] as String).contains(query);
    }).toList();

    if (filteredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contacts,
                size: 64,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _searchQuery.isNotEmpty ? 'No contacts found' : 'No contacts yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Sync your WhatsApp contacts to get started',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = filteredContacts[index];
        return _ContactCard(
          contact: contact,
          onTap: () => _showContactDetails(context, contact),
        );
      },
    );
  }

  void _showContactDetails(BuildContext context, Map<String, String> contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              contact['name'] ?? '',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (contact['pushname'] != null && contact['pushname']!.isNotEmpty)
              Text(
                contact['pushname']!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.primary),
              title: Text(contact['phone'] ?? ''),
              subtitle: const Text('Mobile'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.campaign),
                    label: const Text('Add to Campaign'),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onTap});

  final Map<String, String> contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          contact['phone'] ?? '',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      ),
    );
  }
}

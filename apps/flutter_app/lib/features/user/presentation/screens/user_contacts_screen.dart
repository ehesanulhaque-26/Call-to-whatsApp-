import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../whatsapp/presentation/providers/whatsapp_provider.dart';

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
    final whatsAppState = ref.watch(whatsAppProvider);
    final contacts = whatsAppState.contacts;
    final syncStatus = whatsAppState.contactSyncStatus;
    final activeSession = whatsAppState.activeSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: true,
        actions: [
          if (activeSession != null && whatsAppState.isConnected)
            IconButton(
              icon: syncStatus == ContactSyncStatus.syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: syncStatus == ContactSyncStatus.syncing
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(whatsAppProvider.notifier)
                          .syncContacts(activeSession.sessionId);
                    },
              tooltip: 'Refresh Contacts',
            ),
        ],
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

          // Sync status indicator
          if (whatsAppState.isConnected && contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      if (syncStatus == ContactSyncStatus.syncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.sync, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        syncStatus == ContactSyncStatus.syncing
                            ? 'Syncing contacts...'
                            : syncStatus == ContactSyncStatus.completed
                                ? '${whatsAppState.lastSyncedContactCount} contacts synced'
                                : 'Tap refresh to sync contacts',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Contacts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                final session = activeSession;
                if (session != null && whatsAppState.isConnected) {
                  await ref
                      .read(whatsAppProvider.notifier)
                      .syncContacts(session.sessionId);
                }
              },
              child: _buildContactsList(contacts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList(List<WhatsAppContact> contacts) {
    final filteredContacts = contacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return (c.name ?? '').toLowerCase().contains(query) ||
          (c.pushName ?? '').toLowerCase().contains(query) ||
          c.phone.contains(query);
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

  void _showContactDetails(BuildContext context, WhatsAppContact contact) {
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
              child: contact.profilePictureUrl != null
                  ? ClipOval(
                      child: Image.network(
                        contact.profilePictureUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : Text(
                      (contact.name ?? contact.pushName ?? '?').isNotEmpty
                          ? (contact.name ?? contact.pushName ?? '?')[0]
                              .toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              contact.name ?? contact.pushName ?? 'Unknown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (contact.name != null &&
                contact.pushName != null &&
                contact.name != contact.pushName)
              Text(
                contact.pushName!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.primary),
              title: Text(contact.phone),
              subtitle: const Text('Mobile'),
            ),
            ListTile(
                leading: const Icon(Icons.chat, color: AppColors.primary),
                title: Text(contact.id),
                subtitle: const Text('WhatsApp ID'),
              ),
            if (contact.isBusiness == true)
              const ListTile(
                leading: Icon(Icons.business, color: AppColors.primary),
                title: Text('Business Account'),
                subtitle: Text('This is a WhatsApp Business account'),
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

  final WhatsAppContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = contact.name ?? contact.pushName ?? '';
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
          backgroundImage: contact.profilePictureUrl != null
              ? NetworkImage(contact.profilePictureUrl!)
              : null,
          child: contact.profilePictureUrl == null
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          name,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          contact.phone,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: contact.isBusiness
            ? const Icon(Icons.business, size: 16, color: AppColors.primary)
            : const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../whatsapp/data/repositories/whatsapp_repository.dart';
import '../../../whatsapp/presentation/providers/whatsapp_provider.dart';

class UserSessionsScreen extends ConsumerStatefulWidget {
  const UserSessionsScreen({super.key});

  @override
  ConsumerState<UserSessionsScreen> createState() => _UserSessionsScreenState();
}

class _UserSessionsScreenState extends ConsumerState<UserSessionsScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsAsyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Sessions'),
        centerTitle: true,
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              const Text('Error loading sessions'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.invalidate(sessionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return _EmptySessions(
              onConnectPhone: () => _showConnectionOptions(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              ref.invalidate(sessionsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _SessionCard(
                  session: session.toOpenWASession(),
                  onTap: () => _showSessionDetails(context, session.toOpenWASession()),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showConnectionOptions(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Connect'),
      ),
    );
  }

  /// Show connection options bottom sheet with Phone and QR options
  void _showConnectionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ConnectionOptionsSheet(),
    );
  }

  /// Show QR connection sheet directly
  void _showQRBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _QRConnectionSheet(),
    );
  }

  void _showSessionDetails(BuildContext context, OpenWASession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionDetailsSheet(session: session),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions({required this.onConnectPhone});

  final VoidCallback onConnectPhone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_android,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No WhatsApp Sessions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Connect your WhatsApp to start sending messages',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onConnectPhone,
              icon: const Icon(Icons.phone_android),
              label: const Text('Connect WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with connection options: Phone Number or QR Code
class _ConnectionOptionsSheet extends StatelessWidget {
  const _ConnectionOptionsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Connect WhatsApp',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose how you want to connect',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Phone Number Option
          _ConnectionOptionCard(
            icon: Icons.phone_android,
            title: 'Phone Number',
            subtitle: 'Connect using your phone number',
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.connectWhatsApp);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          
          // QR Code Option
          _ConnectionOptionCard(
            icon: Icons.qr_code_scanner,
            title: 'QR Code',
            subtitle: 'Scan QR code with WhatsApp',
            color: AppColors.info,
            onTap: () {
              Navigator.pop(context);
              // Close bottom sheet and trigger QR flow
              // The QR flow will be shown after the bottom sheet closes
              _showQRFlow(context);
            },
          ),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
        ],
      ),
    );
  }

  void _showQRFlow(BuildContext context) {
    // Navigate to a screen or show a sheet that starts QR connection
    // For now, we'll show the QR connection sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _QRConnectionSheet(),
    );
  }
}

/// Individual connection option card
class _ConnectionOptionCard extends StatelessWidget {
  const _ConnectionOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final OpenWASession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isConnected = session.status == 'connected';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.textTertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.phone_android,
                  color:
                      isConnected ? AppColors.success : AppColors.textTertiary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name ?? 'WhatsApp Session',
                      style: AppTypography.titleSmall
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.id,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: session.status ?? 'disconnected'),
                  if (session.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(session.createdAt!),
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'connected':
        color = AppColors.success;
        label = 'Connected';
        break;
      case 'disconnected':
        color = AppColors.textTertiary;
        label = 'Disconnected';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Pending';
        break;
      case 'error':
        color = AppColors.error;
        label = 'Error';
        break;
      default:
        color = AppColors.textTertiary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QRConnectionSheet extends ConsumerStatefulWidget {
  const _QRConnectionSheet();

  @override
  ConsumerState<_QRConnectionSheet> createState() => _QRConnectionSheetState();
}

class _QRConnectionSheetState extends ConsumerState<_QRConnectionSheet> {
  Timer? _pollingTimer;
  String? _sessionId;
  String? _qrCode;
  bool _isLoading = true;
  bool _isConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(whatsAppRepositoryProvider);
      final session = await repo.createSession();
      setState(() {
        _sessionId = session.id;
        _isLoading = false;
      });
      _startPolling();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to create session';
      });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isConnected || _sessionId == null) {
        _pollingTimer?.cancel();
        return;
      }

      try {
        final repo = ref.read(whatsAppRepositoryProvider);
        final status = await repo.getSessionStatus(_sessionId!);

        if (status.qr != null || status.qrCode != null) {
          setState(() {
            _qrCode = status.qr ?? status.qrCode;
          });
        }

        if (status.state == 'connected') {
          HapticFeedback.heavyImpact();
          setState(() {
            _isConnected = true;
          });
          _pollingTimer?.cancel();
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pop(context);
            ref.invalidate(sessionsProvider);
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _regenerateQR() async {
    setState(() {
      _qrCode = null;
      _isLoading = true;
    });
    await _createSession();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Connect WhatsApp',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Scan the QR code with your WhatsApp app',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isConnected
                    ? _buildConnectedState()
                    : _error != null
                        ? _buildErrorState()
                        : _buildQRState(),
          ),
          if (_qrCode != null && !_isConnected)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _regenerateQR,
                      child: const Text('Refresh QR'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQRState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_qrCode != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
              ],
            ),
            child: Image.memory(
              base64Decode(_qrCode!.replaceAll('data:image/png;base64,', '')),
              width: 250,
              height: 250,
            ),
          )
        else
          const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Waiting for QR code...',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'QR code expires in 60 seconds',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.warning),
        ),
      ],
    );
  }

  Widget _buildConnectedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 64,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Connected!',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your WhatsApp is now connected',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Connection Error',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _error ?? 'An error occurred',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: _regenerateQR, child: const Text('Try Again')),
      ],
    );
  }
}

class _SessionDetailsSheet extends ConsumerWidget {
  const _SessionDetailsSheet({required this.session});

  final OpenWASession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = session.status == 'connected';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.textTertiary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(
              Icons.phone_android,
              size: 40,
              color: isConnected ? AppColors.success : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            session.name ?? 'WhatsApp Session',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusBadge(status: session.status ?? 'disconnected'),
          const SizedBox(height: AppSpacing.xl),
          _DetailRow(label: 'Session ID', value: session.id),
          if (session.createdAt != null)
            _DetailRow(
              label: 'Connected',
              value: _formatDate(session.createdAt!),
            ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              if (isConnected) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final repo = ref.read(whatsAppRepositoryProvider);
                      await repo.reconnectSession(session.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ref.invalidate(sessionsProvider);
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Connect'),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Session'),
                        content: const Text(
                          'Are you sure you want to delete this session?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final repo = ref.read(whatsAppRepositoryProvider);
                      await repo.deleteSession(session.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ref.invalidate(sessionsProvider);
                      }
                    }
                  },
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (_) {
      return dateStr;
    }
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
          Text(
            label,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style:
                AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

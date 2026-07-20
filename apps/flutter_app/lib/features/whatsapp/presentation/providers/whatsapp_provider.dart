import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/services/secure_storage_service.dart';
import '../../data/models/whatsapp_connection.dart';
import '../../data/repositories/whatsapp_repository.dart';

/// WhatsApp connection state
class WhatsAppState {
  WhatsAppState({
    this.connection,
    this.isLoading = false,
    this.error,
    this.openWAHealthy = false,
  });

  final WhatsAppConnection? connection;
  final bool isLoading;
  final String? error;
  final bool openWAHealthy;

  WhatsAppState copyWith({
    WhatsAppConnection? connection,
    bool? isLoading,
    String? error,
    bool? openWAHealthy,
  }) {
    return WhatsAppState(
      connection: connection ?? this.connection,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      openWAHealthy: openWAHealthy ?? this.openWAHealthy,
    );
  }
}

/// WhatsApp notifier for state management
class WhatsAppNotifier extends StateNotifier<WhatsAppState> {
  WhatsAppNotifier(this._repository, this._secureStorage)
      : super(WhatsAppState()) {
    _initialize();
  }

  final WhatsAppRepository _repository;
  final SecureStorageService _secureStorage;
  Timer? _pollingTimer;
  Timer? _qrRefreshTimer;

  static const _pollInterval = Duration(seconds: 3);

  String? _currentSessionId;

  /// Initialize the state
  Future<void> _initialize() async {
    await checkOpenWAHealth();
    await loadSavedSession();
  }

  /// Check OpenWA server health
  Future<void> checkOpenWAHealth() async {
    final isHealthy = await _repository.checkHealth();
    state = state.copyWith(openWAHealthy: isHealthy);
  }

  /// Load saved session from storage
  Future<void> loadSavedSession() async {
    try {
      final sessionId = _secureStorage.getWhatsAppSessionId();
      if (sessionId != null && sessionId.isNotEmpty) {
        _currentSessionId = sessionId;
        await _checkConnectionStatus();
      }
    } catch (_) {}
  }

  /// Create a new connection
  Future<void> connect() async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      connection: WhatsAppConnection.creating(),
    );

    try {
      final isHealthy = await _repository.checkHealth();
      if (!isHealthy) {
        state = state.copyWith(
          isLoading: false,
          error: 'OpenWA server is unavailable. Please try again later.',
          connection: WhatsAppConnection.error('Server unavailable'),
        );
        return;
      }

      final session = await _repository.createSession();
      _currentSessionId = session.id;
      await _secureStorage.saveWhatsAppSessionId(session.id);

      // Start polling for QR code
      _startPolling();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create connection: ${e.toString()}',
        connection: WhatsAppConnection.error(e.toString()),
      );
    }
  }

  /// Start polling for connection status
  void _startPolling() {
    _stopPolling();
    _pollingTimer =
        Timer.periodic(_pollInterval, (_) => _checkConnectionStatus());
  }

  /// Stop polling
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = null;
  }

  /// Check connection status
  Future<void> _checkConnectionStatus() async {
    if (_currentSessionId == null) return;

    try {
      final status = await _repository.getSessionStatus(_currentSessionId!);

      switch (status.state.toLowerCase()) {
        case 'connected':
        case 'open':
        case 'authenticated':
          _stopPolling();
          state = state.copyWith(
            isLoading: false,
            error: null,
            connection: WhatsAppConnection.connected(
              sessionId: _currentSessionId!,
              name: status.state,
              status: 'Connected',
              isHealthy: true,
              lastConnected: DateTime.now(),
            ),
          );
          break;

        case 'qr':
        case 'qrcode':
        case 'waiting_for_qr':
          final qrCode = status.qr ?? status.qrCode;
          if (qrCode != null && qrCode.isNotEmpty) {
            state = state.copyWith(
              isLoading: false,
              connection: WhatsAppConnection.qrReady(qrCode),
            );
          } else {
            // Try to get QR from dedicated endpoint
            final qr = await _repository.getQRCode(_currentSessionId!);
            state = state.copyWith(
              isLoading: false,
              connection: qr != null
                  ? WhatsAppConnection.qrReady(qr)
                  : WhatsAppConnection.qrReady(''),
            );
          }
          break;

        case 'connecting':
        case 'loading':
        case 'authenticating':
          state = state.copyWith(
            isLoading: false,
            connection: WhatsAppConnection.connecting(),
          );
          break;

        case 'disconnected':
        case 'close':
        case 'closed':
          _stopPolling();
          state = state.copyWith(
            isLoading: false,
            connection: WhatsAppConnection.disconnected(),
          );
          break;

        default:
          // Try to get QR code
          final qr = await _repository.getQRCode(_currentSessionId!);
          if (qr != null && qr.isNotEmpty) {
            state = state.copyWith(
              isLoading: false,
              connection: WhatsAppConnection.qrReady(qr),
            );
          }
      }
    } catch (e) {
      // Don't update state on polling errors to avoid flickering
      debugPrint('Status check error: $e');
    }
  }

  /// Refresh QR code
  Future<void> refreshQR() async {
    if (_currentSessionId == null) {
      await connect();
      return;
    }

    try {
      await _repository.reconnectSession(_currentSessionId!);
    } catch (_) {
      // If reconnect fails, create new session
      await connect();
    }
  }

  /// Reconnect to existing session
  Future<void> reconnect() async {
    if (_currentSessionId == null) {
      await connect();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      connection: WhatsAppConnection.creating(),
    );

    try {
      await _repository.reconnectSession(_currentSessionId!);
      _startPolling();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reconnect: ${e.toString()}',
      );
    }
  }

  /// Disconnect WhatsApp (logout)
  Future<void> disconnect() async {
    if (_currentSessionId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      await _repository.logoutSession(_currentSessionId!);
      _stopPolling();
      _currentSessionId = null;
      await _secureStorage.clearWhatsAppSessionId();

      state = state.copyWith(
        isLoading: false,
        connection: WhatsAppConnection.disconnected(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to disconnect: ${e.toString()}',
      );
    }
  }

  /// Delete connection completely
  Future<void> deleteConnection() async {
    if (_currentSessionId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      await _repository.deleteSession(_currentSessionId!);
      _stopPolling();
      _currentSessionId = null;
      await _secureStorage.clearWhatsAppSessionId();

      state = state.copyWith(
        isLoading: false,
        connection: WhatsAppConnection.disconnected(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete connection: ${e.toString()}',
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

/// Provider for WhatsApp state
final whatsAppProvider =
    StateNotifierProvider<WhatsAppNotifier, WhatsAppState>((ref) {
  final repository = ref.watch(whatsAppRepositoryProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return WhatsAppNotifier(repository, secureStorage);
});

/// Provider for connection state enum
final whatsAppConnectionStateProvider =
    Provider<WhatsAppConnectionState>((ref) {
  final state = ref.watch(whatsAppProvider);
  return state.connection?.state ?? WhatsAppConnectionState.disconnected;
});

/// Provider for is connected
final isWhatsAppConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(whatsAppProvider);
  return state.connection?.isConnected ?? false;
});

/// Provider for sessions list
final sessionsProvider = FutureProvider<List<OpenWASession>>((ref) async {
  // Return empty list - actual implementation would fetch from backend
  return [];
});

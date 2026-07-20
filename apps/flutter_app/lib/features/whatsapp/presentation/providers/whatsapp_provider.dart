import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openwa_saas/core/services/api_client.dart';
import 'package:openwa_saas/core/services/websocket_service.dart';
import 'package:openwa_saas/core/services/supabase_service.dart';
import 'package:openwa_saas/features/whatsapp/data/models/whatsapp_connection.dart';
import 'package:openwa_saas/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:dio/dio.dart';

/// Session status enum
enum WhatsAppStatus {
  disconnected,
  connecting,
  waitingForQr,
  qrReady,
  scanning,
  authenticated,
  connected,
  reconnecting,
  error,
}

/// WhatsApp session model
class WhatsAppSession {
  final String sessionId;
  final WhatsAppStatus status;
  final String? phone;
  final String? deviceName;
  final int messageCount;
  final DateTime? lastActivity;
  final String? qrCode;

  WhatsAppSession({
    required this.sessionId,
    required this.status,
    this.phone,
    this.deviceName,
    this.messageCount = 0,
    this.lastActivity,
    this.qrCode,
  });

  WhatsAppSession copyWith({
    String? sessionId,
    WhatsAppStatus? status,
    String? phone,
    String? deviceName,
    int? messageCount,
    DateTime? lastActivity,
    String? qrCode,
  }) {
    return WhatsAppSession(
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      deviceName: deviceName ?? this.deviceName,
      messageCount: messageCount ?? this.messageCount,
      lastActivity: lastActivity ?? this.lastActivity,
      qrCode: qrCode ?? this.qrCode,
    );
  }

  factory WhatsAppSession.fromJson(Map<String, dynamic> json) {
    return WhatsAppSession(
      sessionId: json['sessionId'] ?? json['session_id'] ?? '',
      status: _parseStatus(json['status'] ?? ''),
      phone: json['phone'],
      deviceName: json['deviceName'] ?? json['device_name'],
      messageCount: json['messageCount'] ?? json['message_count'] ?? 0,
      lastActivity: json['lastActivity'] != null
          ? DateTime.tryParse(json['lastActivity'].toString())
          : null,
      qrCode: json['qrCode'] ?? json['qr_code'],
    );
  }

  static WhatsAppStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'created':
        return WhatsAppStatus.disconnected;
      case 'loading':
        return WhatsAppStatus.connecting;
      case 'qr_generated':
      case 'qrcode':
        return WhatsAppStatus.waitingForQr;
      case 'qr_updated':
        return WhatsAppStatus.qrReady;
      case 'authenticated':
        return WhatsAppStatus.scanning;
      case 'connected':
      case 'ready':
        return WhatsAppStatus.connected;
      case 'disconnected':
        return WhatsAppStatus.disconnected;
      case 'reconnecting':
        return WhatsAppStatus.reconnecting;
      case 'error':
        return WhatsAppStatus.error;
      default:
        return WhatsAppStatus.disconnected;
    }
  }

  /// Convert to OpenWASession for backward compatibility
  OpenWASession toOpenWASession() {
    return OpenWASession(
      id: sessionId,
      name: deviceName,
      status: status.name,
      createdAt: lastActivity?.toIso8601String(),
    );
  }

  /// Convert to WhatsAppConnection for backward compatibility
  WhatsAppConnection toWhatsAppConnection() {
    switch (status) {
      case WhatsAppStatus.disconnected:
        return WhatsAppConnection.disconnected();
      case WhatsAppStatus.connecting:
        return WhatsAppConnection.connecting();
      case WhatsAppStatus.waitingForQr:
      case WhatsAppStatus.qrReady:
        return qrCode != null ? WhatsAppConnection.qrReady(qrCode!) : WhatsAppConnection.connecting();
      case WhatsAppStatus.scanning:
      case WhatsAppStatus.authenticated:
        return WhatsAppConnection.connecting();
      case WhatsAppStatus.connected:
        return WhatsAppConnection.connected(
          sessionId: sessionId,
          name: deviceName,
          phone: phone,
          lastConnected: lastActivity,
        );
      case WhatsAppStatus.reconnecting:
        return WhatsAppConnection.connecting();
      case WhatsAppStatus.error:
        return WhatsAppConnection.error('Connection error');
    }
  }
}

/// WhatsApp provider state
class WhatsAppState {
  final List<WhatsAppSession> sessions;
  final WhatsAppSession? activeSession;
  final ConnectionState connectionState;
  final String? error;
  final bool isLoading;

  WhatsAppState({
    this.sessions = const [],
    this.activeSession,
    this.connectionState = ConnectionState.disconnected,
    this.error,
    this.isLoading = false,
  });

  /// Get primary connection (for backward compatibility)
  WhatsAppConnection? get connection {
    if (activeSession != null) {
      return activeSession!.toWhatsAppConnection();
    }
    if (sessions.isNotEmpty) {
      return sessions.first.toWhatsAppConnection();
    }
    return null;
  }

  /// Check if OpenWA is healthy (for backward compatibility)
  bool get openWAHealthy {
    return connectionState == ConnectionState.connected;
  }

  /// Check if connected (for backward compatibility)
  bool get isConnected {
    return connectionState == ConnectionState.connected;
  }

  WhatsAppState copyWith({
    List<WhatsAppSession>? sessions,
    WhatsAppSession? activeSession,
    ConnectionState? connectionState,
    String? error,
    bool? isLoading,
  }) {
    return WhatsAppState(
      sessions: sessions ?? this.sessions,
      activeSession: activeSession ?? this.activeSession,
      connectionState: connectionState ?? this.connectionState,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// WhatsApp notifier
class WhatsAppNotifier extends StateNotifier<WhatsAppState> {
  final Ref ref;
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<ConnectionState>? _connectionSub;
  StreamSubscription<SessionEvent>? _eventSub;
  StreamSubscription<Map<String, dynamic>>? _qrSub;
  StreamSubscription<String>? _errorSub;

  WhatsAppNotifier(this.ref) : super(WhatsAppState()) {
    _init();
  }

  ApiClient get _apiClient => ref.read(apiClientProvider);

  void _init() {
    _connectionSub = _wsService.connectionStateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
      if (connState == ConnectionState.connected) {
        loadSessions();
      }
    });

    _eventSub = _wsService.eventStream.listen(_handleSessionEvent);
    _qrSub = _wsService.qrStream.listen(_handleQrEvent);
    _errorSub = _wsService.errorStream.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  void _handleSessionEvent(SessionEvent event) {
    final sessionId = event.sessionId;
    final data = event.data ?? {};

    final existingIndex = state.sessions.indexWhere((s) => s.sessionId == sessionId);
    WhatsAppSession session;

    if (existingIndex >= 0) {
      session = state.sessions[existingIndex];
    } else {
      session = WhatsAppSession(sessionId: sessionId, status: WhatsAppStatus.disconnected);
    }

    WhatsAppSession updatedSession;
    switch (event.type) {
      case SessionEventType.sessionCreated:
      case SessionEventType.sessionLoading:
        updatedSession = session.copyWith(status: WhatsAppStatus.connecting);
        break;
      case SessionEventType.qrGenerated:
      case SessionEventType.qrUpdated:
        updatedSession = session.copyWith(
          status: WhatsAppStatus.qrReady,
          qrCode: data['qr']?.toString(),
        );
        break;
      case SessionEventType.qrExpired:
        updatedSession = session.copyWith(status: WhatsAppStatus.waitingForQr, qrCode: null);
        break;
      case SessionEventType.authenticated:
        updatedSession = session.copyWith(status: WhatsAppStatus.scanning);
        break;
      case SessionEventType.connected:
      case SessionEventType.ready:
        updatedSession = session.copyWith(
          status: WhatsAppStatus.connected,
          phone: data['phone']?.toString(),
          qrCode: null,
          lastActivity: DateTime.now(),
        );
        break;
      case SessionEventType.disconnected:
        updatedSession = session.copyWith(status: WhatsAppStatus.disconnected);
        break;
      case SessionEventType.reconnecting:
        updatedSession = session.copyWith(status: WhatsAppStatus.reconnecting);
        break;
      case SessionEventType.destroyed:
        final sessions = List<WhatsAppSession>.from(state.sessions);
        sessions.removeWhere((s) => s.sessionId == sessionId);
        state = state.copyWith(sessions: sessions, activeSession: null);
        return;
      case SessionEventType.error:
        state = state.copyWith(error: data['message']?.toString());
        updatedSession = session.copyWith(status: WhatsAppStatus.error);
        break;
      default:
        return;
    }

    final sessions = List<WhatsAppSession>.from(state.sessions);
    if (existingIndex >= 0) {
      sessions[existingIndex] = updatedSession;
    } else {
      sessions.add(updatedSession);
    }

    state = state.copyWith(
      sessions: sessions,
      activeSession: state.activeSession?.sessionId == sessionId ? updatedSession : state.activeSession,
    );
  }

  void _handleQrEvent(Map<String, dynamic> data) {
    final sessionId = data['sessionId']?.toString();
    final qr = data['qr']?.toString();

    if (sessionId == null) return;

    final index = state.sessions.indexWhere((s) => s.sessionId == sessionId);
    if (index < 0) return;

    final session = state.sessions[index].copyWith(
      status: WhatsAppStatus.qrReady,
      qrCode: qr,
    );

    final sessions = List<WhatsAppSession>.from(state.sessions);
    sessions[index] = session;

    state = state.copyWith(
      sessions: sessions,
      activeSession: state.activeSession?.sessionId == sessionId ? session : state.activeSession,
    );
  }

  /// Connect to WebSocket and start listening for events
  Future<void> connect() async {
    final supabaseService = ref.read(supabaseServiceProvider);
    final user = supabaseService.currentUser;

    if (user == null) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    final session = supabaseService.currentSession;
    if (session == null) {
      state = state.copyWith(error: 'No session available');
      return;
    }

    state = state.copyWith(connectionState: ConnectionState.connecting);
    _wsService.connect(session.accessToken);
    
    // Also load existing sessions via REST API
    await loadSessions();
  }

  /// Disconnect WebSocket
  void disconnect() {
    _wsService.disconnect();
    state = state.copyWith(connectionState: ConnectionState.disconnected);
  }

  /// Load sessions from backend via REST API
  Future<void> loadSessions() async {
    try {
      state = state.copyWith(isLoading: true);
      final response = await _apiClient.get<Map<String, dynamic>>('/sessions');
      
      if (response.data != null && response.data!['sessions'] != null) {
        final sessionsList = (response.data!['sessions'] as List)
            .map((s) => WhatsAppSession.fromJson(s as Map<String, dynamic>))
            .toList();
        
        state = state.copyWith(
          sessions: sessionsList,
          isLoading: false,
        );
        
        // Set first session as active if none set
        if (state.activeSession == null && sessionsList.isNotEmpty) {
          state = state.copyWith(activeSession: sessionsList.first);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to load sessions',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load sessions: $e',
      );
    }
  }

  /// Create a new WhatsApp session via REST API
  Future<WhatsAppSession?> createSession({String? name}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/sessions',
        data: {'sessionName': name},
      );
      
      if (response.data != null) {
        final session = WhatsAppSession.fromJson(response.data!);
        
        // Add to sessions list
        final sessions = List<WhatsAppSession>.from(state.sessions)..add(session);
        state = state.copyWith(
          sessions: sessions,
          activeSession: session,
          isLoading: false,
        );
        
        // After creating session, fetch QR code
        await getQRCode(session.sessionId);
        
        return session;
      }
      
      state = state.copyWith(isLoading: false);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to create session',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create session: $e',
      );
      return null;
    }
  }

  /// Get QR code for a session via REST API
  Future<String?> getQRCode(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/sessions/$sessionId/qr',
      );
      
      if (response.data != null && response.data!['qr'] != null) {
        final qr = response.data!['qr'] as String;
        
        // Update session with QR code
        _updateSessionStatus(sessionId, WhatsAppStatus.qrReady, qrCode: qr);
        
        state = state.copyWith(isLoading: false);
        return qr;
      }
      
      state = state.copyWith(isLoading: false);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to get QR code',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to get QR code: $e',
      );
      return null;
    }
  }

  /// Refresh QR code
  Future<void> refreshQR(String sessionId) async {
    await getQRCode(sessionId);
  }

  /// Initialize session
  Future<void> initSession(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      await _apiClient.post<Map<String, dynamic>>(
        '/sessions/$sessionId/init',
      );
      
      // Refresh status
      await getSessionStatus(sessionId);
      
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to initialize session',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize session: $e',
      );
    }
  }

  /// Get session status
  Future<void> getSessionStatus(String sessionId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/sessions/$sessionId/status',
      );
      
      if (response.data != null) {
        final statusData = response.data!;
        final sessionState = statusData['state'] as String? ?? 'DISCONNECTED';
        final qr = statusData['qr'] as String?;
        final phone = statusData['phone'] as String?;
        
        final status = _parseStatus(sessionState);
        _updateSessionStatus(sessionId, status, qrCode: qr, phone: phone);
      }
    } catch (e) {
      // Silently fail for status check
    }
  }

  /// Reconnect a session
  Future<void> reconnect(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      _updateSessionStatus(sessionId, WhatsAppStatus.reconnecting);
      
      await _apiClient.post<Map<String, dynamic>>(
        '/sessions/$sessionId/reconnect',
      );
      
      // Poll for status updates
      _pollSessionStatus(sessionId);
      
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to reconnect',
      );
      _updateSessionStatus(sessionId, WhatsAppStatus.error);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reconnect: $e',
      );
      _updateSessionStatus(sessionId, WhatsAppStatus.error);
    }
  }

  Timer? _statusPollTimer;
  
  void _pollSessionStatus(String sessionId) {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final session = state.sessions.firstWhere(
        (s) => s.sessionId == sessionId,
        orElse: () => WhatsAppSession(sessionId: sessionId, status: WhatsAppStatus.disconnected),
      );
      
      if (session.status == WhatsAppStatus.connected || session.status == WhatsAppStatus.error) {
        timer.cancel();
        return;
      }
      
      await getSessionStatus(sessionId);
    });
  }

  /// Logout a session (disconnect but keep session data)
  Future<void> logout(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      _updateSessionStatus(sessionId, WhatsAppStatus.disconnected);
      
      await _apiClient.post<Map<String, dynamic>>(
        '/sessions/$sessionId/logout',
      );
      
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to logout',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to logout: $e',
      );
    }
  }

  /// Destroy a session completely (delete)
  Future<void> destroySession(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      await _apiClient.delete<Map<String, dynamic>>(
        '/sessions/$sessionId',
      );
      
      // Remove from sessions list
      final sessions = List<WhatsAppSession>.from(state.sessions);
      sessions.removeWhere((s) => s.sessionId == sessionId);
      
      state = state.copyWith(
        sessions: sessions,
        activeSession: state.activeSession?.sessionId == sessionId ? null : state.activeSession,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to delete session',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete session: $e',
      );
    }
  }

  /// Delete connection (alias for destroySession)
  void deleteConnection(String sessionId) {
    destroySession(sessionId);
  }

  /// Sync contacts
  Future<void> syncContacts(String sessionId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      await _apiClient.post<Map<String, dynamic>>(
        '/sessions/$sessionId/sync-contacts',
      );
      
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to sync contacts',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to sync contacts: $e',
      );
    }
  }

  /// Send text message
  Future<bool> sendTextMessage(String sessionId, String to, String text) async {
    try {
      state = state.copyWith(error: null);
      
      await _apiClient.post<Map<String, dynamic>>(
        '/sessions/$sessionId/send-text',
        data: {'to': to, 'text': text},
      );
      
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: e.message ?? 'Failed to send message');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to send message: $e');
      return false;
    }
  }

  /// Send media message
  Future<bool> sendMediaMessage(String sessionId, String to, String mediaUrl, {String? caption}) async {
    try {
      state = state.copyWith(error: null);
      
      await _apiClient.post<Map<String, dynamic>>(
        '/sessions/$sessionId/send-media',
        data: {'to': to, 'mediaUrl': mediaUrl, 'caption': caption},
      );
      
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: e.message ?? 'Failed to send media');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to send media: $e');
      return false;
    }
  }

  void _updateSessionStatus(String sessionId, WhatsAppStatus status, {String? qrCode, String? phone}) {
    final index = state.sessions.indexWhere((s) => s.sessionId == sessionId);
    if (index < 0) return;

    final updatedSession = state.sessions[index].copyWith(
      status: status,
      qrCode: qrCode,
      phone: phone,
    );

    final sessions = List<WhatsAppSession>.from(state.sessions);
    sessions[index] = updatedSession;

    state = state.copyWith(
      sessions: sessions,
      activeSession: state.activeSession?.sessionId == sessionId ? updatedSession : state.activeSession,
    );
  }

  void setActiveSession(WhatsAppSession? session) {
    state = state.copyWith(activeSession: session);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _connectionSub?.cancel();
    _eventSub?.cancel();
    _qrSub?.cancel();
    _errorSub?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}

/// Provider
final whatsAppProvider = StateNotifierProvider<WhatsAppNotifier, WhatsAppState>((ref) {
  return WhatsAppNotifier(ref);
});

/// Convenience providers
final sessionsProvider = Provider<List<WhatsAppSession>>((ref) {
  return ref.watch(whatsAppProvider).sessions;
});

final activeSessionProvider = Provider<WhatsAppSession?>((ref) {
  return ref.watch(whatsAppProvider).activeSession;
});

final connectionStateProvider = Provider<ConnectionState>((ref) {
  return ref.watch(whatsAppProvider).connectionState;
});

final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(whatsAppProvider).connectionState == ConnectionState.connected;
});

final whatsAppConnectionProvider = Provider<WhatsAppConnection?>((ref) {
  return ref.watch(whatsAppProvider).connection;
});

/// Async sessions provider for backward compatibility
/// Returns AsyncValue<List<WhatsAppSession>>
final sessionsAsyncProvider = Provider<AsyncValue<List<WhatsAppSession>>>((ref) {
  final state = ref.watch(whatsAppProvider);
  return AsyncValue.data(state.sessions);
});

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openwa_saas/core/services/websocket_service.dart';
import 'package:openwa_saas/core/services/supabase_service.dart';
import 'package:openwa_saas/features/whatsapp/data/models/whatsapp_connection.dart';
import 'package:openwa_saas/features/whatsapp/data/repositories/whatsapp_repository.dart';

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

  void _init() {
    _connectionSub = _wsService.connectionStateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
      if (connState == ConnectionState.connected) {
        _wsService.getSessions();
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
  }

  void disconnect() {
    _wsService.disconnect();
  }

  Future<void> createSession({String? name}) async {
    if (!_wsService.isConnected) {
      await connect();
    }
    state = state.copyWith(isLoading: true);
    _wsService.createSession(sessionName: name);
    state = state.copyWith(isLoading: false);
  }

  void getQRCode(String sessionId) {
    _wsService.getQR(sessionId);
  }

  void refreshQR(String sessionId) {
    _wsService.getQR(sessionId);
  }

  void initSession(String sessionId) {
    _wsService.initSession(sessionId);
  }

  void reconnect(String sessionId) {
    _wsService.reconnect(sessionId);
  }

  void logout(String sessionId) {
    _wsService.logout(sessionId);
  }

  void destroySession(String sessionId) {
    _wsService.destroySession(sessionId);
  }

  void deleteConnection(String sessionId) {
    _wsService.destroySession(sessionId);
  }

  void syncContacts(String sessionId) {
    _wsService.syncContacts(sessionId);
  }

  void setActiveSession(WhatsAppSession? session) {
    state = state.copyWith(activeSession: session);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
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

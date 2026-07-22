import 'dart:async';
import 'dart:developer' as developer;
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

/// Phone pairing flow status
enum PhonePairingStatus {
  idle,
  preparingSession,
  sessionReady,
  requestingPairingCode,
  pairingCodeReady,
  pairing,
  connected,
  failed,
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
      status: parseStatus(json['status'] ?? ''),
      phone: json['phone'],
      deviceName: json['deviceName'] ?? json['device_name'],
      messageCount: json['messageCount'] ?? json['message_count'] ?? 0,
      lastActivity: json['lastActivity'] != null
          ? DateTime.tryParse(json['lastActivity'].toString())
          : null,
      qrCode: json['qrCode'] ?? json['qr_code'],
    );
  }

  /// Parse status string to WhatsAppStatus enum
  /// Handles both UPPERCASE and lowercase status values from backend
  static WhatsAppStatus parseStatus(String status) {
    final normalizedStatus = status.toUpperCase();
    switch (normalizedStatus) {
      case 'NOT_CREATED':
      case 'CREATING':
        return WhatsAppStatus.disconnected;
      case 'INITIALIZING':
      case 'LOADING':
        return WhatsAppStatus.connecting;
      case 'QR_READY':
      case 'QR_GENERATED':
      case 'QRCODE':
        return WhatsAppStatus.waitingForQr;
      case 'QR_UPDATED':
        return WhatsAppStatus.qrReady;
      case 'AUTHENTICATED':
      case 'PAIRING_READY':
        return WhatsAppStatus.scanning;
      case 'CONNECTING':
        return WhatsAppStatus.connecting;
      case 'CONNECTED':
      case 'READY':
        return WhatsAppStatus.connected;
      case 'DISCONNECTED':
        return WhatsAppStatus.disconnected;
      case 'RECONNECTING':
        return WhatsAppStatus.reconnecting;
      case 'FAILED':
      case 'ERROR':
        return WhatsAppStatus.error;
      case 'LOGGED_OUT':
      case 'DELETED':
        return WhatsAppStatus.disconnected;
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
  final bool? serverHealthy; // null = unknown, true = healthy, false = unhealthy

  // Phone pairing state
  final PhonePairingStatus phonePairingStatus;
  final String? pairingCode;
  final String? pairingPhoneNumber;
  final String? pairingError;

  WhatsAppState({
    this.sessions = const [],
    this.activeSession,
    this.connectionState = ConnectionState.disconnected,
    this.error,
    this.isLoading = false,
    this.serverHealthy,
    this.phonePairingStatus = PhonePairingStatus.idle,
    this.pairingCode,
    this.pairingPhoneNumber,
    this.pairingError,
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
    return serverHealthy ?? false;
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
    bool? serverHealthy,
    PhonePairingStatus? phonePairingStatus,
    String? pairingCode,
    String? pairingPhoneNumber,
    String? pairingError,
  }) {
    return WhatsAppState(
      sessions: sessions ?? this.sessions,
      activeSession: activeSession ?? this.activeSession,
      connectionState: connectionState ?? this.connectionState,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      serverHealthy: serverHealthy ?? this.serverHealthy,
      phonePairingStatus: phonePairingStatus ?? this.phonePairingStatus,
      pairingCode: pairingCode,
      pairingPhoneNumber: pairingPhoneNumber,
      pairingError: pairingError,
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

    // Check server health on init
    checkServerHealth();
  }

  /// Check server health by calling the health endpoint
  Future<void> checkServerHealth() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/health');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final status = data['status'] as String?;
        final openwaService = data['services']?['openwa'] as Map<String, dynamic>?;
        final isHealthy = status == 'healthy' && openwaService?['status'] == 'up';
        state = state.copyWith(serverHealthy: isHealthy);
      } else {
        state = state.copyWith(serverHealthy: false);
      }
    } catch (e) {
      state = state.copyWith(serverHealthy: false);
    }
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
      final response = await _apiClient.get<Map<String, dynamic>>('/openwa/sessions');
      
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
  /// This calls the backend which creates the session in OpenWA and returns the QR code
  Future<WhatsAppSession?> createSession({String? name}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final sessionName = name ?? 'wa-${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/openwa/sessions',
        data: {'name': sessionName},
      );
      
      if (response.data != null) {
        // The backend returns the session with QR code already
        final sessionId = response.data!['id'] ?? response.data!['sessionId'] ?? sessionName;
        final qr = response.data!['qr'] as String?;
        final status = response.data!['status'] as String? ?? 'QR_READY';
        
        // Create a session object from the response
        final session = WhatsAppSession(
          sessionId: sessionId.toString(),
          status: WhatsAppSession.parseStatus(status),
          qrCode: qr,
        );
        
        // Add to sessions list
        final sessions = List<WhatsAppSession>.from(state.sessions)..add(session);
        state = state.copyWith(
          sessions: sessions,
          activeSession: session,
          isLoading: false, // Stop loading immediately after getting QR
        );
        
        developer.log('[WhatsAppProvider] createSession: Session created with QR: ${qr != null}', name: 'Session');
        
        return session;
      }
      
      state = state.copyWith(isLoading: false, error: 'No data returned from server');
      return null;
    } on DioException catch (e) {
      developer.log('[WhatsAppProvider] createSession DioException: ${e.type}, ${e.message}', name: 'Session');
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Failed to create session',
      );
      return null;
    } catch (e) {
      developer.log('[WhatsAppProvider] createSession Exception: $e', name: 'Session');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create session: $e',
      );
      return null;
    }
  }

  /// Get QR code for a session via REST API
  /// Note: This endpoint returns QR from the backend's session state, not directly from OpenWA
  Future<String?> getQRCode(String sessionId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/openwa/sessions/$sessionId/status',
      );
      
      if (response.data != null) {
        final qr = response.data!['qr'] as String?;
        final state = response.data!['state'] as String? ?? 'DISCONNECTED';
        
        // Update session with QR code and status
        _updateSessionStatus(sessionId, WhatsAppSession.parseStatus(state), qrCode: qr);
        
        return qr;
      }
      
      return null;
    } on DioException catch (e) {
      developer.log('[WhatsAppProvider] getQRCode DioException: ${e.type}', name: 'Session');
      return null;
    } catch (e) {
      developer.log('[WhatsAppProvider] getQRCode Exception: $e', name: 'Session');
      return null;
    }
  }

  /// Refresh QR code
  Future<void> refreshQR(String sessionId) async {
    await getQRCode(sessionId);
  }

  /// Initialize session (WebSocket-based, no REST call needed)
  Future<void> initSession(String sessionId) async {
    // Session initialization is handled via WebSocket
    // Just refresh the status to get QR code
    await getSessionStatus(sessionId);
  }

  /// Get session status
  Future<void> getSessionStatus(String sessionId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/openwa/sessions/$sessionId/status',
      );
      
      if (response.data != null) {
        final statusData = response.data!;
        final sessionState = statusData['state'] as String? ?? 'DISCONNECTED';
        final qr = statusData['qr'] as String?;
        final phone = statusData['phone'] as String?;
        
        final status = WhatsAppSession.parseStatus(sessionState);
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
        '/openwa/sessions/$sessionId/reconnect',
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
        '/openwa/sessions/$sessionId/logout',
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
        '/openwa/sessions/$sessionId',
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
        '/openwa/sessions/$sessionId/sync-contacts',
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
        '/openwa/sessions/$sessionId/send-text',
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
        '/openwa/sessions/$sessionId/send-media',
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

  // =====================================================
  // PHONE PAIRING FLOW
  // =====================================================

  Timer? _phonePairingPollTimer;

  /// Start the phone pairing flow
  /// This method handles:
  /// 1. Finding or creating a session
  /// 2. Waiting for session to be ready
  /// 3. Requesting the pairing code
  /// 4. Polling for connection status
  Future<void> startPhonePairing(String phoneNumber) async {
    developer.log('[WhatsAppProvider] Starting phone pairing for: $phoneNumber', name: 'PhonePairing');

    // Cancel any ongoing pairing
    cancelPhonePairing();

    // Reset pairing state
    state = state.copyWith(
      phonePairingStatus: PhonePairingStatus.preparingSession,
      pairingCode: null,
      pairingPhoneNumber: phoneNumber,
      pairingError: null,
    );

    try {
      // Step 1: Find or create a session
      String? sessionId = await _findOrCreateSession();
      
      if (sessionId == null) {
        developer.log('[WhatsAppProvider] Failed to create session', name: 'PhonePairing');
        state = state.copyWith(
          phonePairingStatus: PhonePairingStatus.failed,
          pairingError: 'Failed to create session',
        );
        return;
      }

      developer.log('[WhatsAppProvider] Session ready: $sessionId', name: 'PhonePairing');
      
      // Step 2: Wait for session to be ready (poll status)
      bool sessionReady = await _waitForSessionReady(sessionId);
      
      if (!sessionReady) {
        developer.log('[WhatsAppProvider] Session did not become ready', name: 'PhonePairing');
        state = state.copyWith(
          phonePairingStatus: PhonePairingStatus.failed,
          pairingError: 'Session failed to initialize',
        );
        return;
      }

      // Step 3: Request pairing code
      state = state.copyWith(phonePairingStatus: PhonePairingStatus.requestingPairingCode);
      
      String? pairingCode = await _requestPairingCode(sessionId, phoneNumber);
      
      if (pairingCode == null) {
        developer.log('[WhatsAppProvider] Failed to get pairing code', name: 'PhonePairing');
        return;
      }

      // Step 4: Poll for connection
      state = state.copyWith(
        phonePairingStatus: PhonePairingStatus.pairing,
        pairingCode: pairingCode,
      );

      developer.log('[WhatsAppProvider] Pairing code received: $pairingCode, waiting for connection...', name: 'PhonePairing');

      // Poll for connection - this will update state to connected when done
      _pollForConnection(sessionId);

    } catch (e) {
      developer.log('[WhatsAppProvider] Phone pairing error: $e', name: 'PhonePairing');
      state = state.copyWith(
        phonePairingStatus: PhonePairingStatus.failed,
        pairingError: e.toString(),
      );
    }
  }

  /// Find an existing healthy session or create a new one
  Future<String?> _findOrCreateSession() async {
    developer.log('[WhatsAppProvider] Finding or creating session...', name: 'PhonePairing');

    // Check for existing healthy sessions
    final existingSessions = state.sessions;
    for (final session in existingSessions) {
      if (session.status == WhatsAppStatus.connected ||
          session.status == WhatsAppStatus.qrReady ||
          session.status == WhatsAppStatus.waitingForQr ||
          session.status == WhatsAppStatus.disconnected) {
        developer.log('[WhatsAppProvider] Reusing existing session: ${session.sessionId}', name: 'PhonePairing');
        return session.sessionId;
      }
    }

    // No healthy session found, create a new one
    developer.log('[WhatsAppProvider] No healthy session found, creating new session...', name: 'PhonePairing');
    
    try {
      // Use the createSession method
      await createSession();
      
      // Wait a bit for the session to be created
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Find the newly created session
      final newSessions = state.sessions;
      if (newSessions.isNotEmpty) {
        return newSessions.first.sessionId;
      }
      
      return null;
    } catch (e) {
      developer.log('[WhatsAppProvider] Failed to create session: $e', name: 'PhonePairing');
      return null;
    }
  }

  /// Wait for session to be ready for pairing
  Future<bool> _waitForSessionReady(String sessionId) async {
    developer.log('[WhatsAppProvider] Waiting for session to be ready...', name: 'PhonePairing');
    
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);
    
    for (int i = 0; i < maxAttempts; i++) {
      if (!mounted) return false;
      
      // Check current state
      final session = state.sessions.firstWhere(
        (s) => s.sessionId == sessionId,
        orElse: () => WhatsAppSession(sessionId: sessionId, status: WhatsAppStatus.disconnected),
      );

      // Session is ready if it's in one of these states
      if (session.status == WhatsAppStatus.qrReady ||
          session.status == WhatsAppStatus.waitingForQr ||
          session.status == WhatsAppStatus.disconnected ||
          session.status == WhatsAppStatus.connecting) {
        developer.log('[WhatsAppProvider] Session is ready (attempt ${i + 1})', name: 'PhonePairing');
        state = state.copyWith(phonePairingStatus: PhonePairingStatus.sessionReady);
        return true;
      }

      if (session.status == WhatsAppStatus.connected) {
        developer.log('[WhatsAppProvider] Session already connected', name: 'PhonePairing');
        state = state.copyWith(phonePairingStatus: PhonePairingStatus.connected);
        return true;
      }

      if (session.status == WhatsAppStatus.error) {
        developer.log('[WhatsAppProvider] Session error', name: 'PhonePairing');
        return false;
      }

      await Future.delayed(pollInterval);
    }

    developer.log('[WhatsAppProvider] Timeout waiting for session ready', name: 'PhonePairing');
    return false;
  }

  /// Request a pairing code from the backend
  Future<String?> _requestPairingCode(String sessionId, String phoneNumber) async {
    developer.log('[WhatsAppProvider] ========================================', name: 'PhonePairing');
    developer.log('[WhatsAppProvider] Requesting pairing code for session: $sessionId', name: 'PhonePairing');
    developer.log('[WhatsAppProvider] Received phone number: $phoneNumber', name: 'PhonePairing');
    
    // Backend handles all normalization (strips +, spaces, etc.)
    // Just send the phone as-is
    developer.log('[WhatsAppProvider] Sent to backend: $phoneNumber', name: 'PhonePairing');
    developer.log('[WhatsAppProvider] ========================================', name: 'PhonePairing');

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/openwa/sessions/$sessionId/pairing-code',
        data: {'phoneNumber': phoneNumber},
      );

      developer.log('[WhatsAppProvider] Pairing code response status: ${response.statusCode}', name: 'PhonePairing');
      developer.log('[WhatsAppProvider] Pairing code response data: ${response.data}', name: 'PhonePairing');

      if (response.data != null) {
        final pairingCode = response.data!['pairingCode'] as String?;
        final status = response.data!['status'] as String?;
        
        developer.log('[WhatsAppProvider] Pairing code: $pairingCode, status: $status', name: 'PhonePairing');
        
        if (pairingCode != null) {
          state = state.copyWith(
            phonePairingStatus: PhonePairingStatus.pairingCodeReady,
            pairingCode: pairingCode,
          );
          return pairingCode;
        }
      }

      developer.log('[WhatsAppProvider] No pairing code in response', name: 'PhonePairing');
      state = state.copyWith(
        phonePairingStatus: PhonePairingStatus.failed,
        pairingError: 'Failed to get pairing code',
      );
      return null;
    } on DioException catch (e) {
      developer.log('[WhatsAppProvider] Dio error: ${e.type}, message: ${e.message}', name: 'PhonePairing');
      developer.log('[WhatsAppProvider] Response: ${e.response?.data}', name: 'PhonePairing');
      
      String errorMessage = 'Failed to request pairing code';
      final statusCode = e.response?.statusCode;
      
      if (statusCode == 400) {
        errorMessage = 'Invalid phone number format';
      } else if (statusCode == 404) {
        errorMessage = 'Session not found';
      } else if (statusCode == 409) {
        errorMessage = 'Session already connected';
      } else if (statusCode == 408) {
        errorMessage = 'Pairing request timed out';
      } else if (statusCode == 403) {
        errorMessage = 'Pairing rejected by WhatsApp';
      } else if (statusCode == 503) {
        errorMessage = 'OpenWA server unavailable';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout. Please check your internet.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Server response timeout. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Connection error. Please check your internet.';
      } else {
        errorMessage = e.message ?? 'Unknown error occurred';
      }

      developer.log('[WhatsAppProvider] Error message: $errorMessage', name: 'PhonePairing');
      state = state.copyWith(
        phonePairingStatus: PhonePairingStatus.failed,
        pairingError: errorMessage,
      );
      return null;
    } catch (e, stackTrace) {
      developer.log('[WhatsAppProvider] Unexpected error: $e', name: 'PhonePairing');
      developer.log('[WhatsAppProvider] Stack trace: $stackTrace', name: 'PhonePairing');
      state = state.copyWith(
        phonePairingStatus: PhonePairingStatus.failed,
        pairingError: e.toString(),
      );
      return null;
    }
  }

  /// Poll for connection status after pairing code is received
  void _pollForConnection(String sessionId) {
    developer.log('[WhatsAppProvider] Starting connection polling...', name: 'PhonePairing');
    
    _phonePairingPollTimer?.cancel();
    _phonePairingPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Check if already connected or failed
      if (state.phonePairingStatus == PhonePairingStatus.connected ||
          state.phonePairingStatus == PhonePairingStatus.failed) {
        timer.cancel();
        return;
      }

      try {
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/openwa/sessions/$sessionId/status',
        );

        if (response.data != null) {
          final statusData = response.data!;
          final sessionState = statusData['state'] as String? ?? 'DISCONNECTED';
          final phone = statusData['phone'] as String?;

          final status = WhatsAppSession.parseStatus(sessionState);
          _updateSessionStatus(sessionId, status, phone: phone);

          developer.log('[WhatsAppProvider] Polling status: $sessionState', name: 'PhonePairing');

          if (status == WhatsAppStatus.connected) {
            developer.log('[WhatsAppProvider] Connected! Stopping polling.', name: 'PhonePairing');
            timer.cancel();
            state = state.copyWith(
              phonePairingStatus: PhonePairingStatus.connected,
              connectionState: ConnectionState.connected,
            );
          }
        }
      } catch (e) {
        developer.log('[WhatsAppProvider] Polling error: $e', name: 'PhonePairing');
      }
    });
  }

  /// Cancel ongoing phone pairing flow
  void cancelPhonePairing() {
    developer.log('[WhatsAppProvider] Cancelling phone pairing', name: 'PhonePairing');
    
    _phonePairingPollTimer?.cancel();
    _phonePairingPollTimer = null;
    
    state = state.copyWith(
      phonePairingStatus: PhonePairingStatus.idle,
      pairingCode: null,
      pairingPhoneNumber: null,
      pairingError: null,
    );
  }

  /// Reset pairing state (call after navigating away)
  void resetPhonePairing() {
    cancelPhonePairing();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _phonePairingPollTimer?.cancel();
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

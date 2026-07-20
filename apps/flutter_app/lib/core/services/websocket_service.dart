import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:openwa_saas/core/config/app_config.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

enum SessionEventType {
  sessionCreated,
  sessionLoading,
  qrGenerated,
  qrUpdated,
  qrExpired,
  authenticated,
  connected,
  ready,
  disconnected,
  reconnecting,
  destroyed,
  error,
  contactSyncProgress,
  contactSyncComplete,
  incomingMessage,
  outgoingMessage,
}

class SessionEvent {
  final SessionEventType type;
  final String sessionId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  SessionEvent({
    required this.type,
    required this.sessionId,
    this.data,
    required this.timestamp,
  });

  factory SessionEvent.fromJson(String type, String sessionId, Map<String, dynamic> data) {
    final eventType = _parseEventType(type);
    return SessionEvent(
      type: eventType,
      sessionId: sessionId,
      data: data,
      timestamp: DateTime.now(),
    );
  }

  static SessionEventType _parseEventType(String type) {
    switch (type) {
      case 'session_created':
        return SessionEventType.sessionCreated;
      case 'session_loading':
        return SessionEventType.sessionLoading;
      case 'qr_generated':
        return SessionEventType.qrGenerated;
      case 'qr_updated':
        return SessionEventType.qrUpdated;
      case 'qr_expired':
        return SessionEventType.qrExpired;
      case 'authenticated':
        return SessionEventType.authenticated;
      case 'connected':
        return SessionEventType.connected;
      case 'ready':
        return SessionEventType.ready;
      case 'disconnected':
        return SessionEventType.disconnected;
      case 'reconnecting':
        return SessionEventType.reconnecting;
      case 'destroyed':
        return SessionEventType.destroyed;
      case 'error':
        return SessionEventType.error;
      case 'contact_sync_progress':
        return SessionEventType.contactSyncProgress;
      case 'contact_sync_complete':
        return SessionEventType.contactSyncComplete;
      case 'incoming_message':
        return SessionEventType.incomingMessage;
      case 'outgoing_message':
        return SessionEventType.outgoingMessage;
      default:
        return SessionEventType.error;
    }
  }
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  io.Socket? _socket;
  ConnectionState _connectionState = ConnectionState.disconnected;
  
  final _eventController = StreamController<SessionEvent>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _qrController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<SessionEvent> get eventStream => _eventController.stream;
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get qrStream => _qrController.stream;
  Stream<String> get errorStream => _errorController.stream;
  ConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == ConnectionState.connected;

  void connect(String token) {
    if (_socket != null && _connectionState == ConnectionState.connected) {
      return;
    }

    
    _connectionState = ConnectionState.connecting;
    _connectionStateController.add(_connectionState);

    const wsUrl = AppConfig.wsUrl;

    _socket = io.io(
      wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({
            'Authorization': 'Bearer $token',
          })
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[WebSocket] Connected');
      _connectionState = ConnectionState.connected;
      _connectionStateController.add(_connectionState);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[WebSocket] Disconnected');
      _connectionState = ConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
    });

    _socket!.onConnectError((error) {
      debugPrint('[WebSocket] Connection error: $error');
      _connectionState = ConnectionState.error;
      _connectionStateController.add(_connectionState);
      _errorController.add(error.toString());
    });

    _socket!.onError((error) {
      debugPrint('[WebSocket] Error: $error');
      _connectionState = ConnectionState.error;
      _connectionStateController.add(_connectionState);
    });

    // Listen to session events
    _setupSessionListeners();

    _socket!.connect();
  }

  void _setupSessionListeners() {
    // Session events
    final sessionEvents = [
      'session_created',
      'session_loading',
      'qr_generated',
      'qr_updated',
      'qr_expired',
      'authenticated',
      'connected',
      'ready',
      'disconnected',
      'reconnecting',
      'destroyed',
      'error',
      'contact_sync_progress',
      'contact_sync_complete',
      'incoming_message',
      'outgoing_message',
    ];

    for (final eventName in sessionEvents) {
      _socket!.on(eventName, (data) {
        debugPrint('[WebSocket] Event: $eventName - $data');
        
        final sessionId = data is Map ? (data['sessionId'] ?? '') : '';
        
        final event = SessionEvent.fromJson(
          eventName,
          sessionId.toString(),
          data is Map ? Map<String, dynamic>.from(data) : {},
        );
        
        _eventController.add(event);

        // Handle QR events specially
        if (eventName == 'qr_generated' || eventName == 'qr_updated') {
          final qr = event.data?['qr'];
          if (qr != null) {
            _qrController.add({'sessionId': sessionId, 'qr': qr});
          }
        }
      });
    }

    // Sessions state (on connect)
    _socket!.on('sessions_state', (data) {
      debugPrint('[WebSocket] Sessions state: $data');
    });

    // Session list
    _socket!.on('sessions_list', (data) {
      debugPrint('[WebSocket] Sessions list: $data');
    });

    // Contacts synced
    _socket!.on('contacts_synced', (data) {
      debugPrint('[WebSocket] Contacts synced: $data');
    });

    // Admin stats
    _socket!.on('admin_stats', (data) {
      debugPrint('[WebSocket] Admin stats: $data');
    });

    // Generic error
    _socket!.on('error', (data) {
      debugPrint('[WebSocket] Error event: $data');
      if (data is Map && data['message'] != null) {
        _errorController.add(data['message'].toString());
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionState = ConnectionState.disconnected;
    _connectionStateController.add(_connectionState);
  }

  // Session operations
  void createSession({String? sessionName}) {
    _socket?.emitWithAck('create_session', {'sessionName': sessionName}, ack: (data) {
      debugPrint('[WebSocket] create_session ack: $data');
    },);
  }

  void getQR(String sessionId) {
    _socket?.emitWithAck('get_qr', {'sessionId': sessionId}, ack: (data) {
      debugPrint('[WebSocket] get_qr ack: $data');
    },);
  }

  void initSession(String sessionId) {
    _socket?.emitWithAck('init_session', {'sessionId': sessionId}, ack: (data) {
      debugPrint('[WebSocket] init_session ack: $data');
    },);
  }

  void reconnect(String sessionId) {
    _socket?.emitWithAck('reconnect', {'sessionId': sessionId}, ack: (data) {
      debugPrint('[WebSocket] reconnect ack: $data');
    },);
  }

  void logout(String sessionId) {
    _socket?.emitWithAck('logout', {'sessionId': sessionId}, ack: (data) {
      debugPrint('[WebSocket] logout ack: $data');
    },);
  }

  void destroySession(String sessionId) {
    _socket?.emitWithAck('destroy_session', {'sessionId': sessionId}, ack: (data) {
      debugPrint('[WebSocket] destroy_session ack: $data');
    },);
  }

  void syncContacts(String sessionId) {
    _socket?.emitWithAck('sync_contacts', {'sessionId': sessionId}, ack: (data) {
      debugPrint('[WebSocket] sync_contacts ack: $data');
    },);
  }

  void getSessions() {
    _socket?.emitWithAck('get_sessions', {}, ack: (data) {
      debugPrint('[WebSocket] get_sessions ack: $data');
    },);
  }

  void getStatus(String sessionId) {
    _socket?.emitWithAck('get_status', {'sessionId': sessionId}, ack: (data) {
      debugPrint('[WebSocket] get_status ack: $data');
    },);
  }

  // Admin operations
  void getAdminStats() {
    _socket?.emitWithAck('admin_get_stats', {}, ack: (data) {
      debugPrint('[WebSocket] admin_get_stats ack: $data');
    },);
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _connectionStateController.close();
    _qrController.close();
    _errorController.close();
  }
}

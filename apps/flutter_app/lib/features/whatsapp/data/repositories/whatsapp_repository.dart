import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_client.dart';

/// OpenWA API response types
class OpenWASession {
  final String id;
  final String? name;
  final String? status;
  final String? createdAt;

  OpenWASession({
    required this.id,
    this.name,
    this.status,
    this.createdAt,
  });

  factory OpenWASession.fromJson(Map<String, dynamic> json) => OpenWASession(
        id: json['id'] as String? ?? '',
        name: json['name'] as String?,
        status: json['status'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

class OpenWASessionStatus {
  final String state;
  final String? qr;
  final String? qrCode;

  OpenWASessionStatus({
    required this.state,
    this.qr,
    this.qrCode,
  });

  factory OpenWASessionStatus.fromJson(Map<String, dynamic> json) =>
      OpenWASessionStatus(
        state: json['state'] as String? ?? 'disconnected',
        qr: json['qr'] as String?,
        qrCode: json['qr_code'] as String?,
      );
}

/// WhatsApp repository for API calls
class WhatsAppRepository {
  WhatsAppRepository(this._apiClient);
  final ApiClient _apiClient;

  /// Check OpenWA server health
  Future<bool> checkHealth() async {
    try {
      final response = await _apiClient.get('/api/v1/openwa/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Create a new WhatsApp session
  Future<OpenWASession> createSession() async {
    final response = await _apiClient.post('/api/v1/openwa/sessions');
    if (response.statusCode == 201 || response.statusCode == 200) {
      return OpenWASession.fromJson(response.data);
    }
    throw Exception('Failed to create session');
  }

  /// Get session status
  Future<OpenWASessionStatus> getSessionStatus(String sessionId) async {
    final response =
        await _apiClient.get('/api/v1/openwa/sessions/$sessionId/status');
    return OpenWASessionStatus.fromJson(response.data);
  }

  /// Get QR code for session
  Future<String?> getQRCode(String sessionId) async {
    try {
      final response =
          await _apiClient.get('/api/v1/openwa/sessions/$sessionId/qr');
      if (response.statusCode == 200 && response.data != null) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        return data['qr'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Reconnect session
  Future<bool> reconnectSession(String sessionId) async {
    try {
      final response =
          await _apiClient.post('/api/v1/openwa/sessions/$sessionId/reconnect');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Logout session
  Future<bool> logoutSession(String sessionId) async {
    try {
      final response =
          await _apiClient.post('/api/v1/openwa/sessions/$sessionId/logout');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Delete session
  Future<bool> deleteSession(String sessionId) async {
    try {
      final response =
          await _apiClient.delete('/api/v1/openwa/sessions/$sessionId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Get session info
  Future<OpenWASession?> getSession(String sessionId) async {
    try {
      final response =
          await _apiClient.get('/api/v1/openwa/sessions/$sessionId');
      if (response.statusCode == 200) {
        return OpenWASession.fromJson(response.data);
      }
    } catch (_) {}
    return null;
  }
}

/// Provider for WhatsApp repository
final whatsAppRepositoryProvider = Provider<WhatsAppRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WhatsAppRepository(apiClient);
});

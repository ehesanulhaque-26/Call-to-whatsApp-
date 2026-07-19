import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data
class SecureStorageService {
  SecureStorageService() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }

  late final FlutterSecureStorage _storage;

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyWhatsAppSessionId = 'whatsapp_session_id';

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return _storage.read(key: _keyUserId);
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Check if user is logged in
  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Save WhatsApp session ID
  Future<void> saveWhatsAppSessionId(String sessionId) async {
    await _storage.write(key: _keyWhatsAppSessionId, value: sessionId);
  }

  /// Get WhatsApp session ID
  String? getWhatsAppSessionId() {
    return _storage.read(key: _keyWhatsAppSessionId) as String?;
  }

  /// Clear WhatsApp session ID
  Future<void> clearWhatsAppSessionId() async {
    await _storage.delete(key: _keyWhatsAppSessionId);
  }
}

/// Provider for secure storage
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

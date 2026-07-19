import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data (WhatsApp session only)
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

  static const _keyWhatsAppSessionId = 'whatsapp_session_id';

  /// Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
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

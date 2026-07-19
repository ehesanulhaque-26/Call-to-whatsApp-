import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/env.dart';

/// Supabase service for authentication and data access
class SupabaseService {
  SupabaseService._();
  
  static final SupabaseService _instance = SupabaseService._();
  static SupabaseService get instance => _instance;

  late final SupabaseClient _client;
  SupabaseClient get client => _client;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Supabase
  Future<void> init() async {
    if (_initialized) return;

    // Validate environment configuration before initialization
    Env.validate();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      debug: Env.isDebug,
    );

    _client = Supabase.instance.client;
    _initialized = true;
  }

  /// Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentSession != null;

  /// Auth state changes stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: name != null ? {'name': name} : null,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Reset password for email
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Update user metadata
  Future<User> updateUser({
    String? name,
    String? phone,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;

    final response = await _client.auth.updateUser(UserAttributes(data: updates));
    return response.user!;
  }

  /// Get access token
  String? get accessToken => currentSession?.accessToken;

  /// Refresh session
  Future<Session?> refreshSession() async {
    final response = await _client.auth.refreshSession();
    return response.session;
  }
}

/// Provider for Supabase service
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.instance;
});

import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Auth repository interface
abstract class AuthRepository {
  Future<AuthResponse> login({required String email, required String password});
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  });
  Future<bool> forgotPassword({required String email});
  Future<bool> logout();
  Future<UserProfile?> getCurrentUser();
  Future<UserProfile?> fetchProfile(String userId);
}

/// Auth response
class AuthResponse {
  AuthResponse({
    required this.success,
    this.userId,
    this.email,
    this.name,
    this.role,
    this.error,
  });

  final bool success;
  final String? userId;
  final String? email;
  final String? name;
  final String? role;
  final String? error;
}

/// User profile
class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// Auth repository implementation using Supabase Auth
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._supabaseService);

  final SupabaseService _supabaseService;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('[AuthRepo] LOGIN: Starting for $email', name: 'Auth');

      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      final user = response.user;
      developer.log('[AuthRepo] LOGIN: signIn completed, userId=${user?.id}', name: 'Auth');

      if (user != null) {
        // Get profile in background (don't block login)
        String role = 'user';
        String? profileName;
        
        try {
          final profile = await fetchProfile(user.id);
          if (profile != null) {
            role = profile.role;
            profileName = profile.name;
            developer.log('[AuthRepo] LOGIN: Profile fetched, role=$role', name: 'Auth');
          } else {
            developer.log('[AuthRepo] LOGIN: No profile found', name: 'Auth');
          }
        } catch (e) {
          developer.log('[AuthRepo] LOGIN: Profile fetch error: $e', name: 'Auth');
        }

        return AuthResponse(
          success: true,
          userId: user.id,
          email: user.email ?? '',
          name: profileName ?? user.userMetadata?['name'] ?? '',
          role: role,
        );
      } else {
        developer.log('[AuthRepo] LOGIN: Failed - no user returned', name: 'Auth');
        return AuthResponse(
          success: false,
          error: 'Login failed',
        );
      }
    } on AuthException catch (e) {
      developer.log('[AuthRepo] LOGIN: AuthException: ${e.message}', name: 'Auth');
      return AuthResponse(
        success: false,
        error: e.message,
      );
    } catch (e) {
      developer.log('[AuthRepo] LOGIN: Exception: $e', name: 'Auth');
      return AuthResponse(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  @override
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      developer.log('[AuthRepo] REGISTER: Starting for $email', name: 'Auth');

      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        name: name,
      );

      final user = response.user;
      if (user != null) {
        developer.log('[AuthRepo] REGISTER: Success, userId=${user.id}', name: 'Auth');
        return AuthResponse(
          success: true,
          userId: user.id,
          email: user.email,
          name: name,
          role: 'user',
        );
      } else {
        developer.log('[AuthRepo] REGISTER: Failed - no user returned', name: 'Auth');
        return AuthResponse(
          success: false,
          error: 'Registration failed',
        );
      }
    } on AuthException catch (e) {
      developer.log('[AuthRepo] REGISTER: AuthException: ${e.message}', name: 'Auth');
      return AuthResponse(
        success: false,
        error: e.message,
      );
    } catch (e) {
      developer.log('[AuthRepo] REGISTER: Exception: $e', name: 'Auth');
      return AuthResponse(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  @override
  Future<bool> forgotPassword({required String email}) async {
    try {
      developer.log('[AuthRepo] FORGOT_PASSWORD: Sending to $email', name: 'Auth');
      await _supabaseService.resetPassword(email);
      return true;
    } on AuthException catch (e) {
      developer.log('[AuthRepo] FORGOT_PASSWORD: AuthException: ${e.message}', name: 'Auth');
      throw Exception(e.message);
    } catch (e) {
      developer.log('[AuthRepo] FORGOT_PASSWORD: Exception: $e', name: 'Auth');
      throw Exception('An unexpected error occurred');
    }
  }

  @override
  Future<bool> logout() async {
    try {
      developer.log('[AuthRepo] LOGOUT: Starting', name: 'Auth');
      await _supabaseService.signOut();
      return true;
    } catch (e) {
      developer.log('[AuthRepo] LOGOUT: Exception: $e', name: 'Auth');
      return true;
    }
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        developer.log('[AuthRepo] GET_CURRENT_USER: No user', name: 'Auth');
        return null;
      }

      developer.log('[AuthRepo] GET_CURRENT_USER: userId=${user.id}', name: 'Auth');

      final profile = await fetchProfile(user.id);
      if (profile != null) {
        developer.log('[AuthRepo] GET_CURRENT_USER: Profile found, role=${profile.role}', name: 'Auth');
        return profile;
      }

      // Return default profile if no row found
      developer.log('[AuthRepo] GET_CURRENT_USER: No profile, returning default', name: 'Auth');
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['name'] ?? '',
        role: 'user',
      );
    } catch (e) {
      developer.log('[AuthRepo] GET_CURRENT_USER: Exception: $e', name: 'Auth');
      final user = _supabaseService.currentUser;
      if (user != null) {
        return UserProfile(
          id: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['name'] ?? '',
          role: 'user',
        );
      }
      return null;
    }
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    try {
      developer.log('[AuthRepo] FETCH_PROFILE: Querying for userId=$userId', name: 'Auth');

      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        developer.log('[AuthRepo] FETCH_PROFILE: No row found for userId=$userId', name: 'Auth');
        return null;
      }

      developer.log('[AuthRepo] FETCH_PROFILE: Row found: $response', name: 'Auth');

      return UserProfile(
        id: response['id'] as String,
        email: response['email'] as String? ?? '',
        name: response['name'] as String? ?? '',
        role: response['role'] as String? ?? 'user',
      );
    } catch (e) {
      developer.log('[AuthRepo] FETCH_PROFILE: Exception: $e', name: 'Auth');
      return null;
    }
  }
}

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepositoryImpl(supabaseService);
});

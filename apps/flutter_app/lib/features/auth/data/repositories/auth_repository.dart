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
      developer.log('AuthRepository: Attempting login for $email', name: 'Auth');

      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        developer.log('AuthRepository: Login successful, userId=${user.id}', name: 'Auth');

        // Fetch profile from Supabase profiles table
        final profile = await fetchProfile(user.id);
        final role = profile?.role ?? 'user';

        developer.log('AuthRepository: Fetched profile role=$role', name: 'Auth');

        return AuthResponse(
          success: true,
          userId: user.id,
          email: user.email,
          name: profile?.name ?? user.userMetadata?['name'] ?? '',
          role: role,
        );
      } else {
        developer.log('AuthRepository: Login failed - no user returned', name: 'Auth');
        return AuthResponse(
          success: false,
          error: 'Login failed',
        );
      }
    } on AuthException catch (e) {
      developer.log('AuthRepository: Login failed - ${e.message}', name: 'Auth');
      return AuthResponse(
        success: false,
        error: e.message,
      );
    } catch (e) {
      developer.log('AuthRepository: Login failed - $e', name: 'Auth');
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
      developer.log('AuthRepository: Attempting registration for $email', name: 'Auth');

      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        name: name,
      );

      final user = response.user;
      if (user != null) {
        developer.log('AuthRepository: Registration successful, userId=${user.id}', name: 'Auth');
        return AuthResponse(
          success: true,
          userId: user.id,
          email: user.email,
          name: name,
          role: 'user',
        );
      } else {
        developer.log('AuthRepository: Registration failed - no user returned', name: 'Auth');
        return AuthResponse(
          success: false,
          error: 'Registration failed',
        );
      }
    } on AuthException catch (e) {
      developer.log('AuthRepository: Registration failed - ${e.message}', name: 'Auth');
      return AuthResponse(
        success: false,
        error: e.message,
      );
    } catch (e) {
      developer.log('AuthRepository: Registration failed - $e', name: 'Auth');
      return AuthResponse(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  @override
  Future<bool> forgotPassword({required String email}) async {
    try {
      developer.log('AuthRepository: Sending password reset to $email', name: 'Auth');
      await _supabaseService.resetPassword(email);
      return true;
    } on AuthException catch (e) {
      developer.log('AuthRepository: Password reset failed - ${e.message}', name: 'Auth');
      throw Exception(e.message);
    } catch (e) {
      developer.log('AuthRepository: Password reset failed - $e', name: 'Auth');
      throw Exception('An unexpected error occurred');
    }
  }

  @override
  Future<bool> logout() async {
    try {
      developer.log('AuthRepository: Logging out', name: 'Auth');
      await _supabaseService.signOut();
      return true;
    } catch (e) {
      developer.log('AuthRepository: Logout error - $e', name: 'Auth');
      return true; // Logout locally even if API fails
    }
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        developer.log('AuthRepository: getCurrentUser - no authenticated user', name: 'Auth');
        return null;
      }

      developer.log('AuthRepository: getCurrentUser - userId=${user.id}', name: 'Auth');

      return fetchProfile(user.id);
    } catch (e) {
      developer.log('AuthRepository: getCurrentUser failed - $e', name: 'Auth');
      return null;
    }
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    try {
      developer.log('AuthRepository: Fetching profile for userId=$userId', name: 'Auth');

      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        developer.log('AuthRepository: No profile found for userId=$userId', name: 'Auth');
        return null;
      }

      final profile = UserProfile(
        id: response['id'] as String,
        email: response['email'] as String? ?? '',
        name: response['name'] as String? ?? '',
        role: response['role'] as String? ?? 'user',
      );

      developer.log('AuthRepository: Profile fetched - role=${profile.role}', name: 'Auth');

      return profile;
    } catch (e) {
      developer.log('AuthRepository: fetchProfile failed - $e', name: 'Auth');
      return null;
    }
  }
}

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepositoryImpl(supabaseService);
});

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
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        return AuthResponse(
          success: true,
          userId: user.id,
          email: user.email,
          name: user.userMetadata?['name'] ?? '',
          role: 'user', // Will be fetched from profile
        );
      } else {
        return AuthResponse(
          success: false,
          error: 'Login failed',
        );
      }
    } on AuthException catch (e) {
      return AuthResponse(
        success: false,
        error: e.message,
      );
    } catch (e) {
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
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        name: name,
      );

      final user = response.user;
      if (user != null) {
        return AuthResponse(
          success: true,
          userId: user.id,
          email: user.email,
          name: name,
          role: 'user',
        );
      } else {
        return AuthResponse(
          success: false,
          error: 'Registration failed',
        );
      }
    } on AuthException catch (e) {
      return AuthResponse(
        success: false,
        error: e.message,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  @override
  Future<bool> forgotPassword({required String email}) async {
    try {
      await _supabaseService.resetPassword(email);
      return true;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await _supabaseService.signOut();
      return true;
    } catch (e) {
      return true; // Logout locally even if API fails
    }
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) return null;

      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['name'] ?? '',
        role: 'user', // Will be updated when profile is fetched
      );
    } catch (e) {
      return null;
    }
  }
}

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepositoryImpl(supabaseService);
});

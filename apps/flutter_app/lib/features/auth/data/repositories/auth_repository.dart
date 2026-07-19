import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_client.dart';
import '../models/auth_state.dart';

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
    this.accessToken,
    this.refreshToken,
    this.error,
  });

  final bool success;
  final String? userId;
  final String? email;
  final String? name;
  final String? role;
  final String? accessToken;
  final String? refreshToken;
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

/// Auth repository implementation
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data;
      return AuthResponse(
        success: true,
        userId: data['userId'] ?? data['user']?['id'],
        email: data['email'] ?? data['user']?['email'],
        name: data['name'] ?? data['user']?['name'],
        role: data['role'] ?? data['user']?['role'],
        accessToken: data['accessToken'] ?? data['token'],
        refreshToken: data['refreshToken'] ?? data['refresh_token'],
      );
    } on DioException catch (e) {
      final apiException = ApiException.fromDioError(e);
      return AuthResponse(
        success: false,
        error: apiException.message,
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
      final response = await _apiClient.post(
        '/api/v1/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      final data = response.data;
      return AuthResponse(
        success: true,
        userId: data['userId'] ?? data['user']?['id'],
        email: data['email'] ?? data['user']?['email'],
        name: data['name'] ?? data['user']?['name'],
        role: data['role'] ?? data['user']?['role'],
      );
    } on DioException catch (e) {
      final apiException = ApiException.fromDioError(e);
      return AuthResponse(
        success: false,
        error: apiException.message,
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
      await _apiClient.post(
        '/api/v1/auth/forgot-password',
        data: {'email': email},
      );
      return true;
    } on DioException catch (e) {
      final apiException = ApiException.fromDioError(e);
      throw Exception(apiException.message);
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
      return true;
    } catch (e) {
      return true; // Logout locally even if API fails
    }
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/api/v1/users/me');
      final data = response.data;
      return UserProfile(
        id: data['id'],
        email: data['email'],
        name: data['name'],
        role: data['role'],
        createdAt: data['createdAt'] != null
            ? DateTime.parse(data['createdAt'])
            : null,
        updatedAt: data['updatedAt'] != null
            ? DateTime.parse(data['updatedAt'])
            : null,
      );
    } catch (e) {
      return null;
    }
  }
}

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepositoryImpl(apiClient);
});

import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/models/auth_state.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth notifier for managing authentication state using Supabase Auth
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._supabaseService)
      : super(const AuthState());

  final AuthRepository _repository;
  final SupabaseService _supabaseService;

  /// Check authentication status - fetches profile from Supabase
  Future<void> checkAuthStatus() async {
    developer.log('[AuthNotifier] CHECK_AUTH: Starting', name: 'Auth');

    final user = _supabaseService.currentUser;
    if (user == null) {
      developer.log(
        '[AuthNotifier] CHECK_AUTH: No user, clearing state',
        name: 'Auth',
      );
      state = const AuthState();
      return;
    }

    developer.log('[AuthNotifier] CHECK_AUTH: User=${user.id}', name: 'Auth');

    final profile = await _repository.getCurrentUser();

    if (profile != null) {
      state = AuthState(
        isAuthenticated: true,
        userId: user.id,
        email: profile.email,
        name: profile.name,
        role: profile.role,
      );
    } else {
      // No profile found, use defaults
      state = AuthState(
        isAuthenticated: true,
        userId: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['name'] ?? '',
        role: 'user',
      );
    }

    developer.log(
      '[AuthNotifier] CHECK_AUTH: Done, isAuth=${state.isAuthenticated}, role=${state.role}',
      name: 'Auth',
    );
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    developer.log('[AuthNotifier] LOGIN: Starting for $email', name: 'Auth');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.login(
        email: email,
        password: password,
      );

      developer.log(
        '[AuthNotifier] LOGIN: Response success=${response.success}, userId=${response.userId}',
        name: 'Auth',
      );

      if (response.success && response.userId != null) {
        state = AuthState(
          isAuthenticated: true,
          userId: response.userId,
          email: response.email ?? '',
          name: response.name ?? '',
          role: response.role ?? 'user',
        );
        developer.log(
          '[AuthNotifier] LOGIN: Success, role=${state.role}',
          name: 'Auth',
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Login failed',
        );
        return false;
      }
    } catch (e, stack) {
      developer.log(
        '[AuthNotifier] LOGIN: Exception: $e\n$stack',
        name: 'Auth',
      );
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Register new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.register(
        name: name,
        email: email,
        password: password,
      );

      if (response.success) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Registration failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Request password reset
  Future<bool> forgotPassword({required String email}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.forgotPassword(email: email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    developer.log('[AuthNotifier] LOGOUT: Starting', name: 'Auth');
    state = state.copyWith(isLoading: true);

    await _repository.logout();

    state = const AuthState();
    developer.log('[AuthNotifier] LOGOUT: Done', name: 'Auth');
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthNotifier(repository, supabaseService);
});

/// Provider to check if current user is admin
final isAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.role == 'admin';
});

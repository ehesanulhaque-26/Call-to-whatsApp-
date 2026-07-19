import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/models/auth_state.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth notifier for managing authentication state using Supabase Auth
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._supabaseService) : super(const AuthState());

  final AuthRepository _repository;
  final SupabaseService _supabaseService;

  /// Check authentication status
  Future<void> checkAuthStatus() async {
    final user = _supabaseService.currentUser;
    if (user != null) {
      state = state.copyWith(
        isAuthenticated: true,
        userId: user.id,
        email: user.email,
        name: user.userMetadata?['name'] ?? '',
      );

      // Try to get current user profile
      final userProfile = await _repository.getCurrentUser();
      if (userProfile != null) {
        state = state.copyWith(
          email: userProfile.email,
          name: userProfile.name,
          role: userProfile.role,
        );
      }
    }
  }

  /// Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.login(
        email: email,
        password: password,
      );

      if (response.success && response.userId != null) {
        state = AuthState(
          isAuthenticated: true,
          userId: response.userId,
          email: response.email,
          name: response.name,
          role: response.role ?? 'user',
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Login failed',
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

  /// Register
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

  /// Forgot password
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
    state = state.copyWith(isLoading: true);

    await _repository.logout();

    state = const AuthState();
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthNotifier(repository, supabaseService);
});

/// Check if user is admin
final isAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.role == 'admin';
});

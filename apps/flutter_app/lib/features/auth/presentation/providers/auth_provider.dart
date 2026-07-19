import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/models/auth_state.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth notifier for managing authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._secureStorage) : super(const AuthState());

  final AuthRepository _repository;
  final SecureStorageService _secureStorage;

  /// Check authentication status
  Future<void> checkAuthStatus() async {
    final hasValidSession = await _secureStorage.hasValidSession();
    if (hasValidSession) {
      final userId = await _secureStorage.getUserId();
      state = state.copyWith(
        isAuthenticated: true,
        userId: userId,
      );

      // Try to get current user profile
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(
          email: user.email,
          name: user.name,
          role: user.role,
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

      if (response.success && response.accessToken != null) {
        await _secureStorage.saveAccessToken(response.accessToken!);
        if (response.refreshToken != null) {
          await _secureStorage.saveRefreshToken(response.refreshToken!);
        }
        if (response.userId != null) {
          await _secureStorage.saveUserId(response.userId!);
        }

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
    await _secureStorage.clearAll();

    state = const AuthState();
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthNotifier(repository, secureStorage);
});

/// Check if user is admin
final isAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.role == 'admin';
});

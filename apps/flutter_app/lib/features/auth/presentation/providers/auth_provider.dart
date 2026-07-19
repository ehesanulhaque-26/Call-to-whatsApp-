import 'dart:developer' as developer;
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
    developer.log('AuthNotifier: checkAuthStatus called', name: 'Auth');

    final user = _supabaseService.currentUser;
    developer.log('AuthNotifier: currentUser = ${user?.id ?? 'null'}', name: 'Auth');
    
    if (user != null) {
      developer.log('AuthNotifier: User authenticated - userId=${user.id}, email=${user.email}', name: 'Auth');

      // Get current user profile from Supabase
      final userProfile = await _repository.getCurrentUser();
      
      if (userProfile != null) {
        developer.log('AuthNotifier: Profile fetched - role=${userProfile.role}, name=${userProfile.name}', name: 'Auth');

        state = AuthState(
          isAuthenticated: true,
          userId: user.id,
          email: userProfile.email,
          name: userProfile.name,
          role: userProfile.role,
        );
        
        developer.log('AuthNotifier: AuthState updated - isAuthenticated=${state.isAuthenticated}, role=${state.role}', name: 'Auth');
      } else {
        developer.log('AuthNotifier: getCurrentUser returned null - using auth user data', name: 'Auth');

        state = AuthState(
          isAuthenticated: true,
          userId: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['name'] ?? '',
          role: 'user',
        );
        
        developer.log('AuthNotifier: AuthState updated with defaults - role=${state.role}', name: 'Auth');
      }
    } else {
      developer.log('AuthNotifier: No authenticated user in Supabase', name: 'Auth');
    }
  }

  /// Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    developer.log('AuthNotifier: Login started for $email', name: 'Auth');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.login(
        email: email,
        password: password,
      );

      developer.log('AuthNotifier: Repository response - success=${response.success}, userId=${response.userId}', name: 'Auth');

      if (response.success && response.userId != null) {
        developer.log('AuthNotifier: Login successful - userId=${response.userId}, role=${response.role}', name: 'Auth');

        state = AuthState(
          isAuthenticated: true,
          userId: response.userId,
          email: response.email ?? '',
          name: response.name ?? '',
          role: response.role ?? 'user',
        );

        developer.log('AuthNotifier: AuthState after login - isAuthenticated=${state.isAuthenticated}, role=${state.role}', name: 'Auth');
        return true;
      } else {
        developer.log('AuthNotifier: Login failed - ${response.error}', name: 'Auth');
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Login failed',
        );
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('AuthNotifier: Login exception - $e\n$stackTrace', name: 'Auth');
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
      developer.log('AuthNotifier: Registration attempt for $email', name: 'Auth');

      final response = await _repository.register(
        name: name,
        email: email,
        password: password,
      );

      if (response.success) {
        developer.log('AuthNotifier: Registration successful', name: 'Auth');
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        developer.log('AuthNotifier: Registration failed - ${response.error}', name: 'Auth');
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Registration failed',
        );
        return false;
      }
    } catch (e) {
      developer.log('AuthNotifier: Registration exception - $e', name: 'Auth');
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
    developer.log('AuthNotifier: Logout initiated', name: 'Auth');

    state = state.copyWith(isLoading: true);

    await _repository.logout();

    state = const AuthState();

    developer.log('AuthNotifier: Logout complete, state cleared', name: 'Auth');
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

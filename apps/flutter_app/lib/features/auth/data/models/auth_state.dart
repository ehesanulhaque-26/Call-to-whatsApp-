import 'package:equatable/equatable.dart';

/// Authentication state
class AuthState extends Equatable {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userId,
    this.email,
    this.name,
    this.role,
    this.error,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? email;
  final String? name;
  final String? role;
  final String? error;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? email,
    String? name,
    String? role,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isAuthenticated,
        isLoading,
        userId,
        email,
        name,
        role,
        error,
      ];
}

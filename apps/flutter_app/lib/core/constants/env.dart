/// Environment configuration for the Flutter app.
/// All secrets and configuration are read from environment variables.
class Env {
  Env._();

  /// API Base URL - Read from environment variable
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Supabase URL - Read from environment variable
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase Anonymous Key - Read from environment variable
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Whether the app is running in debug mode
  static const bool isDebug = bool.fromEnvironment('DEBUG', defaultValue: false);

  /// App version
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Validate environment configuration
  static bool get isConfigured =>
      apiBaseUrl.isNotEmpty && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

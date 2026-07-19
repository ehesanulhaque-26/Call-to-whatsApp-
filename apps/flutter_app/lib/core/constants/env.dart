/// Environment configuration for the Flutter app.
/// All secrets and configuration are read from environment variables via --dart-define.
class Env {
  Env._();

  /// API Base URL - Read from environment variable
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Supabase URL - Read from environment variable
  /// Required for Supabase initialization
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase Anonymous Key - Read from environment variable
  /// Required for Supabase initialization
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
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Validate and throw if not configured (call at app startup)
  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL is not configured. '
          'Build with --dart-define=SUPABASE_URL=your-supabase-url');
    }
    if (supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is not configured. '
          'Build with --dart-define=SUPABASE_ANON_KEY=your-anon-key');
    }
  }
}

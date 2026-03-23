import '../logging/app_logger.dart';

/// Environment configuration loaded at app startup.
/// Supports compile-time and runtime configuration overrides.
class AppEnvironment {
  static const String _defaultFirebaseDbUrl =
      'https://qr-scanner-app-ca1fb-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Firebase Realtime Database URL (compile-time override via --dart-define).
  static const String firebaseDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue: _defaultFirebaseDbUrl,
  );

  /// Custom environment identifier (defaults to 'production').
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  /// Enable enhanced logging/diagnostics.
  static const String enableDiagnostics = String.fromEnvironment(
    'ENABLE_DIAGNOSTICS',
    defaultValue: 'false',
  );

  /// Whether this is a development build.
  static bool get isDevelopment => environment == 'development';

  /// Whether this is a staging build.
  static bool get isStaging => environment == 'staging';

  /// Whether this is a production build.
  static bool get isProduction => environment == 'production';

  /// Whether diagnostics are enabled.
  static bool get diagnosticsEnabled =>
      enableDiagnostics.toLowerCase() == 'true';

  /// Get a human-readable environment name.
  static String get environmentName => environment.toUpperCase();

  /// Print current environment config to logs (called from bootstrap).
  static void printConfig() {
    final buffer = StringBuffer();
    buffer.writeln('========== APP ENVIRONMENT ==========');
    buffer.writeln('Environment: $environmentName');
    buffer.writeln('Firebase RTDB: $firebaseDatabaseUrl');
    buffer.writeln('Diagnostics: ${diagnosticsEnabled ? 'ENABLED' : 'disabled'}');
    buffer.writeln('=====================================');
    AppLogger.info(buffer.toString(), tag: 'Environment');
  }
}

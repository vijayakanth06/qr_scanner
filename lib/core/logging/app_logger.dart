import 'package:flutter/foundation.dart';

typedef ErrorReporter = Future<void> Function(
  dynamic error,
  StackTrace? stackTrace,
  String message,
  String? tag,
);

/// Structured logging utility for the application.
/// Replaces console debugPrint with categorized, leveled output.
class AppLogger {
  static const String _prefix = '🔵 [QRScanner]';
  static ErrorReporter? _errorReporter;

  static void configure({ErrorReporter? errorReporter}) {
    _errorReporter = errorReporter;
  }

  /// Log info-level message.
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr ℹ️  $message');
    }
  }

  /// Log warning-level message.
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr ⚠️  $message');
    }
  }

  /// Log error with optional stacktrace.
  static void error(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr ❌ Error: $message');
      if (error != null) {
        debugPrint('$_prefix$tagStr    Error detail: $error');
      }
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace, label: '$_prefix$tagStr');
      }
    }

    final reporter = _errorReporter;
    if (reporter != null) {
      reporter(error ?? message, stackTrace, message, tag);
    }
  }

  /// Log debug message (verbose).
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr 🔧 $message');
    }
  }

  /// Log success message.
  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr ✅ $message');
    }
  }
}

import 'package:flutter/material.dart';

import '../errors/scan_error.dart';
import '../../app/theme.dart';

class NotificationService {
  NotificationService() : messengerKey = GlobalKey<ScaffoldMessengerState>();

  final GlobalKey<ScaffoldMessengerState> messengerKey;

  void _showSnackBar({
    required String message,
    required Color accentColor,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    VoidCallback? onRetry,
    bool persistent = false,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final action = onRetry != null
        ? SnackBarAction(
            label: 'Retry',
            onPressed: onRetry,
            textColor: accentColor,
          )
        : SnackBarAction(
            label: 'Dismiss',
            onPressed: () => messenger.hideCurrentSnackBar(),
            textColor: kTextSecondaryColor,
          );

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      duration: persistent ? const Duration(days: 365) : duration,
      backgroundColor: kBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
      ),
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: accentColor),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: kTextPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      action: action,
    );

    messenger.showSnackBar(snackBar);
  }

  void showSuccess(String message) {
    _showSnackBar(
      message: message,
      accentColor: kSuccessColor,
      icon: Icons.check_circle_outline,
    );
  }

  void showError(String message, {VoidCallback? onRetry}) {
    _showSnackBar(
      message: message,
      accentColor: kErrorColor,
      icon: Icons.error_outline,
      onRetry: onRetry,
      persistent: true,
    );
  }

  void showWarning(String message) {
    _showSnackBar(
      message: message,
      accentColor: const Color(0xFFF57C00),
      icon: Icons.warning_amber_rounded,
      duration: const Duration(seconds: 5),
    );
  }

  void showInfo(String message) {
    _showSnackBar(
      message: message,
      accentColor: kPrimaryColor,
      icon: Icons.info_outline,
    );
  }

  void showSyncStatus({required String version, required int recordsUpdated}) {
    final text = 'Synced to v$version · $recordsUpdated records updated';
    _showSnackBar(
      message: text,
      accentColor: kSuccessColor,
      icon: Icons.cloud_done_outlined,
    );
  }

  void showScanFeedback(ScanError error) {
    if (error is MalformedInput) {
      showError('Invalid code: ${error.rawValue}');
    } else if (error is UnknownRoll) {
      showWarning('Unknown student for roll ${error.rollNo}');
    } else if (error is CooldownActive) {
      showWarning('Wait ${error.remainingSeconds}s before rescanning ${error.rollNo}');
    } else if (error is DuplicateExit) {
      showWarning('Exit already recorded for ${error.rollNo}');
    } else if (error is OfflineLookupMiss) {
      showInfo('Offline – ${error.rollNo} not found in cache');
    } else if (error is ScannerHardwareError) {
      showError('Scanner error — tap to retry');
    } else {
      showError('Unexpected scan error. Please try again.');
    }
  }

  void dismiss() {
    messengerKey.currentState?.hideCurrentSnackBar();
  }
}

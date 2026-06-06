import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../core/notifications/notification_service.dart';
import 'sync_progress_sheet.dart';
import '../../sync/sync_service.dart';

class SyncButton extends StatefulWidget {
  const SyncButton({super.key});

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
  bool _isSyncing = false;
  bool _isProgressSheetVisible = false;

  SyncService get _syncService => sl<SyncService>();
  NotificationService get _notifications => sl<NotificationService>();

  bool _shouldShowSyncSheetFor(SyncProgress state) {
    return state is SyncChecking ||
        state is SyncComparing ||
        state is SyncDownloading ||
        state is SyncApplying ||
        state is SyncFailed;
  }

  void _showSyncProgressSheet() {
    if (!mounted || _isProgressSheetVisible) return;

    _isProgressSheetVisible = true;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const SyncProgressSheet(),
    ).whenComplete(() {
      _isProgressSheetVisible = false;
    });
  }

  Future<void> _runSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final progressSubscription = _syncService.progressStream.listen((state) {
      if (_shouldShowSyncSheetFor(state)) {
        _showSyncProgressSheet();
      }
    });

    late final SyncResult result;
    try {
      result = await _syncService.triggerSync();
    } finally {
      await progressSubscription.cancel();
    }

    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (result.success && result.version != null) {
      _notifications.showSyncStatus(
        version: result.version!,
        recordsUpdated: result.recordsUpdated,
      );
    } else if (result.message == 'offline') {
      _notifications.showWarning('Offline — using cached data.');
    } else if (result.message == 'empty') {
      _notifications.showError(
        'No student data available for this college. Contact your administrator.',
      );
    } else if (!result.success) {
      _notifications.showError('Sync failed. Please try again.', onRetry: _runSync);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _isSyncing ? 'Syncing…' : 'Sync students',
      onPressed: _isSyncing ? null : _runSync,
      icon: _isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
    );
  }
}

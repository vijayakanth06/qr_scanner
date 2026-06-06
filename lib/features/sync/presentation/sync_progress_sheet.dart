import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme.dart';
import '../../sync/sync_service.dart';

class SyncProgressSheet extends StatefulWidget {
  const SyncProgressSheet({super.key});

  @override
  State<SyncProgressSheet> createState() => _SyncProgressSheetState();
}

class _SyncProgressSheetState extends State<SyncProgressSheet> {
  late final SyncService _syncService;
  late final Stream<SyncProgress> _stream;

  @override
  void initState() {
    super.initState();
    _syncService = sl<SyncService>();
    _stream = _syncService.progressStream;
  }

  String _labelFor(SyncProgress progress) {
    if (progress is SyncChecking) return 'Checking for updates…';
    if (progress is SyncComparing) return 'Comparing changes…';
    if (progress is SyncDownloading) {
      return progress.full ? 'Downloading full dataset…' : 'Downloading changes…';
    }
    if (progress is SyncApplying) return 'Applying updates to offline cache…';
    if (progress is SyncDone) {
      return 'Done · v${progress.version} · ${progress.recordsUpdated} records';
    }
    if (progress is SyncFailed) return 'Sync failed: ${progress.message}';
    return 'Preparing sync…';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: kBackgroundColor,
        border: Border(top: BorderSide(color: kBorderColor)),
      ),
      child: StreamBuilder<SyncProgress>(
        stream: _stream,
        builder: (context, snapshot) {
          final progress = snapshot.data;
          final label = progress == null ? 'Ready to sync' : _labelFor(progress);
          final isDone = progress is SyncDone;
          final isFailed = progress is SyncFailed;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.cloud_sync_outlined, color: kPrimaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Student data sync',
                    style: TextStyle(
                      color: kTextPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!isDone && !isFailed)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (isDone)
                    const Icon(Icons.check_circle_outline, color: kSuccessColor)
                  else if (isFailed)
                    const Icon(Icons.error_outline, color: kErrorColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: kTextPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(isDone || isFailed ? 'Close' : 'Hide'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

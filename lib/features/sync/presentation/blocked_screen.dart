import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme.dart';
import '../sync_service.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({required this.collegeName, super.key});

  final String collegeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: kPrimaryLightColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Student Data',
                style: TextStyle(
                  color: kTextPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No student data available for $collegeName.\nContact your administrator.',
                style: TextStyle(
                  color: kTextSecondaryColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Sync'),
                onPressed: () async {
                  if (!getIt.isRegistered<SyncService>()) return;
                  final result = await sl<SyncService>().triggerSync();
                  if (!context.mounted) return;
                  if (result.success && result.recordsUpdated > 0) {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

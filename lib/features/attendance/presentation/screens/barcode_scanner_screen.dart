import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

enum ScanOutcomeType {
  successEntry,
  successExit,
  blocked,
  invalid,
  info,
}

class ScanHandleResult {
  const ScanHandleResult({
    required this.shouldCloseScanner,
    required this.type,
    required this.message,
    this.scannedCode,
  });

  final bool shouldCloseScanner;
  final ScanOutcomeType type;
  final String message;
  final String? scannedCode;
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, required this.onScanned});

  final Future<ScanHandleResult> Function(String) onScanned;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: false,
  );

  bool _isScanning = false;
  ScanHandleResult? _lastResult;
  final List<ScanHandleResult> _recentResults = [];
  Timer? _statusClearTimer;

  Future<void> _onBarcodeDetected(BarcodeCapture barcodeCapture) async {
    if (_isScanning) return;

    for (final barcode in barcodeCapture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;

      setState(() => _isScanning = true);
      final code = raw.trim();

      ScanHandleResult result;
      try {
        result = await widget.onScanned(code);
      } catch (_) {
        result = ScanHandleResult(
          shouldCloseScanner: false,
          type: ScanOutcomeType.blocked,
          message: 'Scan processing failed. Please try once again.',
          scannedCode: code,
        );
      }

      if (!mounted) return;

      _pushResult(result);
      await _triggerHaptic(result.type);
      if (!mounted) return;

      if (result.shouldCloseScanner) {
        Navigator.of(context).pop();
      } else {
        setState(() => _isScanning = false);
      }
      break;
    }
  }

  void _pushResult(ScanHandleResult result) {
    _statusClearTimer?.cancel();
    setState(() {
      _lastResult = result;
      _recentResults.insert(0, result);
      if (_recentResults.length > 5) {
        _recentResults.removeRange(5, _recentResults.length);
      }
    });

    _statusClearTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _lastResult = null;
      });
    });
  }

  @override
  void dispose() {
    _statusClearTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _triggerHaptic(ScanOutcomeType type) async {
    var didUseVibratorPlugin = false;
    try {
      final canVibrate = await Vibration.hasVibrator();
      if (canVibrate) {
        didUseVibratorPlugin = true;
        if (type == ScanOutcomeType.successEntry) {
          await Vibration.vibrate(duration: 45, amplitude: 200);
        } else if (type == ScanOutcomeType.successExit) {
          await Vibration.vibrate(duration: 65, amplitude: 225);
        } else if (type == ScanOutcomeType.blocked || type == ScanOutcomeType.invalid) {
          await Vibration.vibrate(pattern: [0, 40, 40, 80]);
        } else {
          await Vibration.vibrate(duration: 30, amplitude: 140);
        }
      }
    } catch (_) {}

    if (didUseVibratorPlugin) {
      return;
    }

    try {
      await HapticFeedback.vibrate();
      if (type == ScanOutcomeType.successEntry || type == ScanOutcomeType.successExit) {
        await HapticFeedback.mediumImpact();
        return;
      }
      if (type == ScanOutcomeType.blocked || type == ScanOutcomeType.invalid) {
        await HapticFeedback.heavyImpact();
        return;
      }
      await HapticFeedback.selectionClick();
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  (Color background, Color foreground, IconData icon, String label) _styleForResult(
    BuildContext context,
    ScanOutcomeType type,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final successScheme = ColorScheme.fromSeed(seedColor: Colors.green);
    if (type == ScanOutcomeType.successEntry) {
      return (successScheme.primary, successScheme.onPrimary, Icons.check_circle_outline, 'ENTRY');
    }
    if (type == ScanOutcomeType.successExit) {
      return (scheme.error, scheme.onError, Icons.logout, 'EXIT');
    }
    if (type == ScanOutcomeType.blocked) {
      return (scheme.secondary, scheme.onSecondary, Icons.block, 'BLOCKED');
    }
    if (type == ScanOutcomeType.invalid) {
      return (scheme.errorContainer, scheme.onErrorContainer, Icons.error_outline, 'INVALID');
    }
    return (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.info_outline, 'INFO');
  }

  String _compactLabel(ScanHandleResult result) {
    final code = result.scannedCode?.trim();
    if (code == null || code.isEmpty) {
      return result.message;
    }
    return '$code • ${result.message}';
  }

  Widget _buildFeedbackPanel() {
    if (_recentResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final active = _lastResult ?? _recentResults.first;
    final activeStyle = _styleForResult(context, active.type);
    final previousItems = _recentResults.skip(1).take(2).toList();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: activeStyle.$1,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Icon(activeStyle.$3, color: activeStyle.$2),
                  const SizedBox(width: 8),
                  Text(
                    activeStyle.$4,
                    style: TextStyle(color: activeStyle.$2, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _compactLabel(active),
                      style: TextStyle(color: activeStyle.$2, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (previousItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in previousItems)
                    Builder(
                      builder: (context) {
                        final style = _styleForResult(context, item.type);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: style.$1.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${style.$4}: ${item.scannedCode ?? '-'}',
                            style: TextStyle(color: style.$2, fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingBadge() {
    if (!_isScanning) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 84,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Processing...'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Align the barcode within the frame and hold steady',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _buildProcessingBadge(),
          _buildFeedbackPanel(),
        ],
      ),
    );
  }
}

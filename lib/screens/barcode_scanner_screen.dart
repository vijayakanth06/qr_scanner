import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String) onScanned;

  const BarcodeScannerScreen({super.key, required this.onScanned});

  @override
  BarcodeScannerScreenState createState() => BarcodeScannerScreenState();
}

class BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _isScanning = false;
  OverlayEntry? _overlayEntry;

  void _onBarcodeDetected(BarcodeCapture barcodeCapture) {
    if (_isScanning) return;

    for (final barcode in barcodeCapture.barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isScanning = true);
        final code = barcode.rawValue!;

        _showTopNotification(code);
        _showExtractedDataNotification(code);

        widget.onScanned(code);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
        break;
      }
    }
  }

  // Shows a roll number notification at the TOP
  void _showTopNotification(String code) {
    _overlayEntry?.remove(); // Remove previous notification if any

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 200, // Move to the top
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '✅ Scanned: $code',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    _overlayEntry?.remove();
                    _overlayEntry = null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    Future.delayed(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  // Shows extracted data notification at the BOTTOM (without blocking buttons)
  void _showExtractedDataNotification(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📄 Extracted: $code', // Replace with department, batch, time if needed
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80, left: 10, right: 10), // Position lower
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2), // Shorter duration for fast scanning
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onBarcodeDetected),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Align the barcode within the frame',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

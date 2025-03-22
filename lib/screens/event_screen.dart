import 'package:flutter/material.dart';
import '../models/attendee.dart';
import 'barcode_scanner_screen.dart';
import '../services/excel_service.dart';
import '../services/settings_service.dart';
import '../utils/data_parser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';


class EventScreen extends StatefulWidget {
  final String eventName;

  const EventScreen({super.key, required this.eventName});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  late Map<String, String> departments;
  Box<Attendee>? attendeeBox; // Nullable to prevent access before initialization

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    departments = await SettingsService.loadDepartments();
    if (!Hive.isBoxOpen('attendees')) {
      await Hive.openBox<Attendee>('attendees'); // Ensure the box is opened
    }
    attendeeBox = Hive.box<Attendee>('attendees');
    setState(() {}); // Ensure UI rebuilds after loading data
  }

  void onQRCodeScanned(String qrData) {
    if (qrData.length < 8) {
      _showMessage('Invalid QR Code');
      return;
    }

    String rollNumber = qrData;
    String batch = extractBatch(rollNumber);
    String department = extractDepartment(rollNumber, departments);
    String time = getCurrentTime();

    final newAttendee = Attendee(
      rollNumber: rollNumber,
      batch: batch,
      department: department,
      time: time,
    );

    attendeeBox?.add(newAttendee); // Ensure box is not null
    setState(() {});
    _showMessage('Saved: Roll: $rollNumber | Batch: $batch | Dept: $department | Time: $time');
  }

  Future<void> exportToExcel() async {
  if (attendeeBox == null || attendeeBox!.isEmpty) {
    _showMessage('No data to export');
    return;
  }

  // Request permission for Android 11+
  if (await Permission.manageExternalStorage.request().isGranted ||
      await Permission.storage.request().isGranted) {
    
    List<Map<String, String>> data = attendeeBox!.values.map((attendee) => {
          'rollNumber': attendee.rollNumber.toString(),
          'batch': attendee.batch.toString(),
          'department': attendee.department.toString(),
          'time': attendee.time.toString(),
        }).toList();

    String filePath = (await ExcelService.generateExcel(data, widget.eventName)); 

    _showMessage('Excel file saved at: $filePath');
  } else {
    _showMessage('Storage permission denied');
    openAppSettings(); // Opens settings for manual permission
  }
}

  void _showMessage(String message) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: kToolbarHeight + 10,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}


  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Hive.openBox<Attendee>('attendees'), // Ensure the box is open before building UI
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(title: Text(widget.eventName)),
          body: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: Hive.box<Attendee>('attendees').listenable(),
                  builder: (context, Box<Attendee> box, _) {
                    if (box.isEmpty) {
                      return const Center(child: Text('No attendees yet.'));
                    }
                    return ListView.builder(
                      itemCount: box.length,
                      itemBuilder: (context, index) {
                        final attendee = box.getAt(index);
                        if (attendee == null) return const SizedBox.shrink();
                        return ListTile(
                          title: Text('Roll: ${attendee.rollNumber}'),
                          subtitle: Text('Batch: ${attendee.batch} | Dept: ${attendee.department}'),
                          trailing: Text(attendee.time),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BarcodeScannerScreen(onScanned: onQRCodeScanned),
                        ),
                      );
                    },
                    child: const Text('Scan QR'),
                  ),
                  ElevatedButton(
                    onPressed: exportToExcel,
                    child: const Text('Export Excel'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

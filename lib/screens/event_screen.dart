import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/attendee.dart';
import '../services/settings_service.dart';
import '../utils/data_parser.dart';
import '../utils/excel_export.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.eventName});

  final String eventName;

  @override
  EventScreenState createState() => EventScreenState();
}

class EventScreenState extends State<EventScreen> {
  Box<Attendee>? attendeeBox;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventName),
      ),
      body: Center(
        child: Text('Event Screen for ${widget.eventName}'),
      ),
    );
  }
  List<Attendee> attendees = [];
  Map<String, String> departments = {};
  final MobileScannerController scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    attendeeBox = await Hive.openBox<Attendee>('attendees');
    departments = await SettingsService.loadDepartments();
    updateAttendeeList();
  }

  void updateAttendeeList() {
    setState(() {
      attendees = attendeeBox?.values.where((a) => a.eventName == widget.eventName).toList() ?? [];
    });
  }

  void onQRCodeScanned(String? qrData) {
    if (qrData == null || qrData.length < 8) {
      _showMessage('Invalid QR Code');
      return;
    }

    String id = qrData;
    DateTime currentTime = DateTime.now();
    String batch = extractBatch(id);
    String department = extractDepartment(id, departments);
    
    // ✅ Fix: Ensure `name` is assigned (Replace "Unknown" if real name is available)
    String name = "Unknown"; 

    Attendee? existingAttendee = attendeeBox!.values.firstWhere(
      (a) => a.id == id && a.eventName == widget.eventName,
      orElse: () => Attendee.empty(),
    );

    if (existingAttendee.id.isNotEmpty) {
      existingAttendee.outTime = currentTime;
      existingAttendee.save();
      _showMessage('Exit Recorded: ID: $id | Out Time: ${getCurrentTime()}');
    } else {
      attendeeBox?.add(
        Attendee(
          id: id,
          name: name, // ✅ Fixed missing `name` field
          batch: batch,
          department: department,
          inTime: currentTime,
          outTime: null,
          eventName: widget.eventName,
        ),
      );
      _showMessage('Entry Recorded: ID: $id | Time: ${getCurrentTime()}');
    }

    updateAttendeeList();
  }

  void exportToExcel() {
    if (attendees.isEmpty) {
      _showMessage('No attendees to export');
      return;
    }
    exportAttendeesToExcel(attendees, widget.eventName);
    _showMessage('Excel exported successfully');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}

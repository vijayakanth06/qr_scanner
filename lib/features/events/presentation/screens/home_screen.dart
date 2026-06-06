import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_scanner/core/logging/app_logger.dart';
import 'package:qr_scanner/core/config/college_config.dart';
import 'package:qr_scanner/app/di.dart';
import 'package:qr_scanner/features/sync/presentation/sync_button.dart';
import 'package:qr_scanner/app/theme.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../../data/hive_event_repository.dart';
import '../../../attendance/domain/entities/attendee.dart';
import '../../../attendance/presentation/screens/event_screen.dart';
import '../../../students/domain/entities/student.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Box<Event>? eventBox;
  EventRepository? eventRepository;
  String _activeCollegeId = 'default';

  String get _eventsBoxName => 'events_$_activeCollegeId';
  String get _attendeesBoxName => 'attendees_$_activeCollegeId';

  @override
  void initState() {
    super.initState();
    _initializeBox();
  }

  Future<void> _initializeBox() async {
    final prefs = sl<SharedPreferences>();
    final selectedCollegeId = prefs.getString('selectedCollegeId')?.trim() ?? '';
    _activeCollegeId = selectedCollegeId.isEmpty ? 'default' : selectedCollegeId;

    if (Hive.isBoxOpen(_eventsBoxName)) {
      eventBox = Hive.box<Event>(_eventsBoxName);
    } else {
      eventBox = await Hive.openBox<Event>(_eventsBoxName);
    }
    eventRepository = HiveEventRepository(eventBox!);
    setState(() {});
  }

  Future<void> createEvent(
    String name,
    String venue,
    ScanMode scanMode,
    int cooldownSeconds,
    bool restrictDuplicateExit,
  ) async {
    if (eventRepository == null) {
      _showMessage('Events are still loading. Please try again.');
      return;
    }

    if (name.trim().isEmpty || venue.trim().isEmpty) {
      _showMessage('Event name and venue are required.');
      return;
    }

    final event = Event(
      name: name.trim(),
      venue: venue.trim(),
      date: DateTime.now(),
      scanMode: scanMode,
      cooldownSeconds: cooldownSeconds,
      restrictDuplicateExit: restrictDuplicateExit,
    );

    try {
      await eventRepository!.add(event);
      if (!mounted) return;
      _showMessage('Event "${event.name}" created.');
      setState(() {});
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to create event.',
        tag: 'HomeScreen',
        error: error,
        stackTrace: stackTrace,
      );
      _showMessage('Failed to create event. Please try again.');
    }
  }

  Future<void> deleteEvent(int index) async {
    if (eventBox == null || eventRepository == null) return;
    final event = eventRepository!.getAt(index);
    if (event == null) return;

    final attendeeBox = Hive.isBoxOpen(_attendeesBoxName)
      ? Hive.box<Attendee>(_attendeesBoxName)
      : await Hive.openBox<Attendee>(_attendeesBoxName);
    attendeeBox.deleteAll(
      attendeeBox.keys.where((key) {
        final attendee = attendeeBox.get(key);
        return attendee != null && attendee.eventName == event.name;
      }).toList(),
    );

    await eventRepository!.deleteAt(index);
    _showMessage('Event "${event.name}" deleted.');
    setState(() {});
  }

  void navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) => setState(() {}));
  }

  void _showMessage(String message) {
    final lower = message.toLowerCase();
    final isError = lower.contains('failed') || lower.contains('error') || lower.contains('denied');
    final isSuccess = lower.contains('success') ||
        lower.contains('synced') ||
        lower.contains('saved') ||
        lower.contains('updated') ||
        lower.contains('completed') ||
        lower.contains('created') ||
        lower.contains('deleted');

    final backgroundColor = isError
        ? const Color(0xFFD32F2F)
        : isSuccess
            ? const Color(0xFF2E7D32)
            : const Color(0xFF1565C0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _switchCollege() async {
    final prefs = sl<SharedPreferences>();
    final oldCollegeId = prefs.getString('selectedCollegeId')?.trim() ?? '';

    await prefs.remove('selectedCollegeId');
    await Hive.box<Student>('students').clear();
    await prefs.remove('localVersion');

    if (oldCollegeId.isNotEmpty) {
      final oldEventsBoxName = 'events_$oldCollegeId';
      final oldAttendeesBoxName = 'attendees_$oldCollegeId';

      if (Hive.isBoxOpen(oldEventsBoxName)) {
        final oldEvents = Hive.box<Event>(oldEventsBoxName);
        await oldEvents.clear();
        await oldEvents.close();
      } else if (await Hive.boxExists(oldEventsBoxName)) {
        final oldEvents = await Hive.openBox<Event>(oldEventsBoxName);
        await oldEvents.clear();
        await oldEvents.close();
      }

      if (Hive.isBoxOpen(oldAttendeesBoxName)) {
        final oldAttendees = Hive.box<Attendee>(oldAttendeesBoxName);
        await oldAttendees.clear();
        await oldAttendees.close();
      } else if (await Hive.boxExists(oldAttendeesBoxName)) {
        final oldAttendees = await Hive.openBox<Attendee>(oldAttendeesBoxName);
        await oldAttendees.clear();
        await oldAttendees.close();
      }
    }

    if (getIt.isRegistered<CollegeConfig>()) {
      getIt.unregister<CollegeConfig>();
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/pick-college', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Events'),
        titleTextStyle: const TextStyle(
          color: kTextPrimaryColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          const SyncButton(),
          PopupMenuButton<String>(
            iconColor: kPrimaryColor,
            onSelected: (value) {
              if (value == 'switch_college') {
                _switchCollege();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'switch_college',
                child: Text('Switch College'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            color: kPrimaryColor,
            onPressed: navigateToSettings,
          ),
        ],
      ),
      body: eventBox == null
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<Box<Event>>(
              valueListenable: eventBox!.listenable(),
              builder: (context, box, _) {
                if (box.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.event_busy, size: 64, color: kTextDisabledColor),
                          SizedBox(height: 12),
                          Text(
                            'No Events Found',
                            style: TextStyle(
                              color: kTextSecondaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap + to create your first event',
                            style: TextStyle(
                              color: kTextDisabledColor,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final event = box.getAt(index);
                    if (event == null) return const SizedBox.shrink();

                    return ListTile(
                      title: Text(event.name),
                      subtitle: Text(event.venue),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventScreen(event: event),
                          ),
                        );
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDeleteEvent(index, event.name),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _showAddEventDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddEventDialog() {
    final nameController = TextEditingController();
    final venueController = TextEditingController();
    ScanMode selectedMode = ScanMode.both;
    final cooldownController = TextEditingController(text: '3');
    bool restrictDuplicateExit = true;

    return showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, localSetState) => AlertDialog(
          title: const Text(
            'Add Event',
            style: TextStyle(
              color: kTextPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Event Name',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ScanMode>(
                    initialValue: selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Scan Mode',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(value: ScanMode.both, child: Text('Both')), 
                      DropdownMenuItem(value: ScanMode.entryOnly, child: Text('Entry Only')), 
                      DropdownMenuItem(value: ScanMode.exitOnly, child: Text('Exit Only')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      localSetState(() {
                        selectedMode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cooldownController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cooldown (seconds)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Restrict Duplicate Exit',
                          style: const TextStyle(color: kTextPrimaryColor),
                        ),
                      ),
                      Switch(
                        value: restrictDuplicateExit,
                        onChanged: (value) {
                          localSetState(() {
                            restrictDuplicateExit = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty || venueController.text.isEmpty) {
                  _showMessage('Event name and venue are required.');
                  return;
                }
                final cooldown = int.tryParse(cooldownController.text.trim()) ?? 3;
                await createEvent(
                  nameController.text,
                  venueController.text,
                  selectedMode,
                  cooldown < 0 ? 0 : cooldown,
                  restrictDuplicateExit,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEvent(int index, String eventName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$eventName" and all associated data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              deleteEvent(index);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

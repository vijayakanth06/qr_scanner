import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../events/domain/entities/event.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../../data/hive_event_repository.dart';
import '../../../attendance/domain/entities/attendee.dart';
import '../../../attendance/presentation/screens/event_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Box<Event>? eventBox;
  EventRepository? eventRepository;

  @override
  void initState() {
    super.initState();
    _initializeBox();
  }

  Future<void> _initializeBox() async {
    eventBox = await Hive.openBox<Event>('events');
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
    if (eventRepository == null) return;
    final event = Event(
      name: name.trim(),
      venue: venue.trim(),
      date: DateTime.now(),
      scanMode: scanMode,
      cooldownSeconds: cooldownSeconds,
      restrictDuplicateExit: restrictDuplicateExit,
    );

    await eventRepository!.add(event);
    setState(() {});
  }

  Future<void> deleteEvent(int index) async {
    if (eventBox == null || eventRepository == null) return;
    final event = eventRepository!.getAt(index);
    if (event == null) return;

    final attendeeBox = Hive.box<Attendee>('attendees');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: navigateToSettings,
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<Event>>(
        valueListenable: eventBox?.listenable() ?? ValueNotifier(Hive.box<Event>('events')),
        builder: (context, box, _) {
          if (eventBox == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (box.isEmpty) return const Center(child: Text('No Events Found'));

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
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventDialog() {
    final nameController = TextEditingController();
    final venueController = TextEditingController();
    ScanMode selectedMode = ScanMode.both;
    final cooldownController = TextEditingController(text: '3');
    bool restrictDuplicateExit = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, localSetState) => AlertDialog(
          title: const Text('Add Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Event Name'),
                ),
                TextField(
                  controller: venueController,
                  decoration: const InputDecoration(labelText: 'Venue'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ScanMode>(
                  initialValue: selectedMode,
                  decoration: const InputDecoration(labelText: 'Scan Mode'),
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
                TextField(
                  controller: cooldownController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cooldown (seconds)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Restrict Duplicate Exit'),
                  value: restrictDuplicateExit,
                  onChanged: (value) {
                    localSetState(() {
                      restrictDuplicateExit = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isEmpty || venueController.text.isEmpty) {
                  return;
                }
                final cooldown = int.tryParse(cooldownController.text.trim()) ?? 3;
                createEvent(
                  nameController.text,
                  venueController.text,
                  selectedMode,
                  cooldown < 0 ? 0 : cooldown,
                  restrictDuplicateExit,
                );
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

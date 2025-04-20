import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import 'event_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Event> eventBox;

  @override
  void initState() {
    super.initState();
    _initializeBox();
  }

  Future<void> _initializeBox() async {
    eventBox = await Hive.openBox<Event>('events');
    setState(() {});
  }

  Future<void> createEvent(String name, String venue) async {
    final event = Event(
      name: name.trim(),
      venue: venue.trim(),
      date: DateTime.now(),
    );

    await eventBox.add(event);
    setState(() {}); // Refresh UI
  }

  void deleteEvent(int index) {
    final event = eventBox.getAt(index);
    if (event == null) return;

    final attendeeBox = Hive.box('attendees');
    attendeeBox.deleteAll(
      attendeeBox.keys.where((key) {
        final attendee = attendeeBox.get(key);
        return attendee != null && attendee.eventName == event.name;
      }).toList(),
    );

    eventBox.deleteAt(index);
    _showMessage('Event "${event.name}" deleted.');
    setState(() {}); // Refresh UI
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
        valueListenable: eventBox.listenable(),
        builder: (context, box, _) {
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
                      builder: (_) => EventScreen(eventName: event.name),
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

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Event Name')),
            TextField(controller: venueController, decoration: const InputDecoration(labelText: 'Venue')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && venueController.text.isNotEmpty) {
                createEvent(nameController.text, venueController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

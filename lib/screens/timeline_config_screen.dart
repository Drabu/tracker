import 'package:flutter/material.dart';
import '../models/models.dart';

class TimelineConfigScreen extends StatefulWidget {
  const TimelineConfigScreen({super.key});

  @override
  State<TimelineConfigScreen> createState() => _TimelineConfigScreenState();
}

class _TimelineConfigScreenState extends State<TimelineConfigScreen> {
  List<TimelineConfig> _timelines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTimelines();
  }

  Future<void> _loadTimelines() async {
    setState(() => _isLoading = true);
    // TODO: Load from API when backend is ready
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _timelines = [
        TimelineConfig(
          id: 'default',
          name: 'Default Timeline',
          startHour: 6,
          endHour: 23,
          maxPoints: 100,
          panelIds: ['1', '2'],
        ),
        TimelineConfig(
          id: 'work',
          name: 'Work Day',
          startHour: 9,
          endHour: 18,
          maxPoints: 50,
          panelIds: ['1'],
        ),
      ];
      _isLoading = false;
    });
  }

  void _showAddTimelineDialog() {
    final nameController = TextEditingController();
    int startHour = 6;
    int endHour = 23;
    int maxPoints = 100;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Timeline'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Timeline Name'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Start Hour: '),
                    Expanded(
                      child: Slider(
                        value: startHour.toDouble(),
                        min: 0,
                        max: 23,
                        divisions: 23,
                        label: '${startHour.toString().padLeft(2, '0')}:00',
                        onChanged: (v) => setDialogState(() => startHour = v.round()),
                      ),
                    ),
                    Text('${startHour.toString().padLeft(2, '0')}:00'),
                  ],
                ),
                Row(
                  children: [
                    const Text('End Hour: '),
                    Expanded(
                      child: Slider(
                        value: endHour.toDouble(),
                        min: 1,
                        max: 24,
                        divisions: 23,
                        label: '${endHour.toString().padLeft(2, '0')}:00',
                        onChanged: (v) => setDialogState(() => endHour = v.round()),
                      ),
                    ),
                    Text('${endHour.toString().padLeft(2, '0')}:00'),
                  ],
                ),
                Row(
                  children: [
                    const Text('Max Points: '),
                    Expanded(
                      child: Slider(
                        value: maxPoints.toDouble(),
                        min: 10,
                        max: 200,
                        divisions: 19,
                        label: '$maxPoints',
                        onChanged: (v) => setDialogState(() => maxPoints = v.round()),
                      ),
                    ),
                    Text('$maxPoints'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                setState(() {
                  _timelines.add(TimelineConfig(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    startHour: startHour,
                    endHour: endHour,
                    maxPoints: maxPoints,
                  ));
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTimelineDialog(TimelineConfig timeline, int index) {
    final nameController = TextEditingController(text: timeline.name);
    int startHour = timeline.startHour;
    int endHour = timeline.endHour;
    int maxPoints = timeline.maxPoints;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Timeline'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Timeline Name'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Start Hour: '),
                    Expanded(
                      child: Slider(
                        value: startHour.toDouble(),
                        min: 0,
                        max: 23,
                        divisions: 23,
                        label: '${startHour.toString().padLeft(2, '0')}:00',
                        onChanged: (v) => setDialogState(() => startHour = v.round()),
                      ),
                    ),
                    Text('${startHour.toString().padLeft(2, '0')}:00'),
                  ],
                ),
                Row(
                  children: [
                    const Text('End Hour: '),
                    Expanded(
                      child: Slider(
                        value: endHour.toDouble(),
                        min: 1,
                        max: 24,
                        divisions: 23,
                        label: '${endHour.toString().padLeft(2, '0')}:00',
                        onChanged: (v) => setDialogState(() => endHour = v.round()),
                      ),
                    ),
                    Text('${endHour.toString().padLeft(2, '0')}:00'),
                  ],
                ),
                Row(
                  children: [
                    const Text('Max Points: '),
                    Expanded(
                      child: Slider(
                        value: maxPoints.toDouble(),
                        min: 10,
                        max: 200,
                        divisions: 19,
                        label: '$maxPoints',
                        onChanged: (v) => setDialogState(() => maxPoints = v.round()),
                      ),
                    ),
                    Text('$maxPoints'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _timelines.removeAt(index));
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _timelines[index] = timeline.copyWith(
                    name: nameController.text,
                    startHour: startHour,
                    endHour: endHour,
                    maxPoints: maxPoints,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Timelines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimelines,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTimelineDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timelines.isEmpty
              ? const Center(child: Text('No timelines configured. Add one!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _timelines.length,
                  itemBuilder: (context, index) {
                    final timeline = _timelines[index];
                    return Card(
                      key: ValueKey(timeline.name),
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(timeline.name),
                        subtitle: Text(
                          '${timeline.startHour.toString().padLeft(2, '0')}:00 - ${timeline.endHour.toString().padLeft(2, '0')}:00 • ${timeline.maxPoints} max points',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showEditTimelineDialog(timeline, index),
                      ),
                    );
                  },
                ),
    );
  }
}

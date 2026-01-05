import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class HabitListScreen extends StatefulWidget {
  final Function(Habit)? onHabitSelected;
  
  const HabitListScreen({super.key, this.onHabitSelected});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  String get _currentUserId => AuthService.currentUser?.id ?? '';
  List<Habit> _habits = [];
  Set<String> _compoundHabitIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _loadCompoundHabits();
  }

  Future<void> _loadHabits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final habits = await ApiService.getHabits();
      setState(() {
        _habits = habits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompoundHabits() async {
    try {
      final compoundIds = await ApiService.getUserCompoundHabits(_currentUserId);
      setState(() {
        _compoundHabitIds = compoundIds.toSet();
      });
    } catch (e) {
      // Ignore errors, compound habits are optional
    }
  }

  Future<void> _toggleCompound(String habitId, bool isCompound) async {
    try {
      await ApiService.setUserCompoundHabit(_currentUserId, habitId, isCompound);
      setState(() {
        if (isCompound) {
          _compoundHabitIds.add(habitId);
        } else {
          _compoundHabitIds.remove(habitId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAddHabitDialog() {
    final titleController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Habit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Icon (emoji)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
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
            onPressed: () async {
              if (titleController.text.isEmpty || categoryController.text.isEmpty) {
                return;
              }
              try {
                await ApiService.createHabit(
                  title: titleController.text,
                  category: categoryController.text,
                  icon: iconController.text,
                  description: descriptionController.text,
                );
                if (context.mounted) Navigator.pop(context);
                _loadHabits();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditHabitDialog(Habit habit) {
    final titleController = TextEditingController(text: habit.title);
    final categoryController = TextEditingController(text: habit.category);
    final descriptionController = TextEditingController(text: habit.description);
    final iconController = TextEditingController(text: habit.icon);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Habit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Icon (emoji)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Habit?'),
                  content: Text('Are you sure you want to delete "${habit.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await ApiService.deleteHabit(habit.id);
                  if (context.mounted) Navigator.pop(context);
                  _loadHabits();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.updateHabit(habit.id, {
                  'title': titleController.text,
                  'category': categoryController.text,
                  'icon': iconController.text,
                  'description': descriptionController.text,
                });
                if (context.mounted) Navigator.pop(context);
                _loadHabits();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHabits,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHabitDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadHabits,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _habits.isEmpty
                        ? const Center(
                            child: Text('No habits yet. Add one!'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _habits.length,
                            itemBuilder: (context, index) {
                              final habit = _habits[index];
                              return Card(
                                key: ValueKey(habit.id),
                                child: ListTile(
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _compoundHabitIds.contains(habit.id),
                                        onChanged: (value) => _toggleCompound(habit.id, value ?? false),
                                        activeColor: const Color(0xFFFF9F0A),
                                      ),
                                      if (habit.icon.isNotEmpty)
                                        Text(
                                          habit.icon,
                                          style: const TextStyle(fontSize: 24),
                                        )
                                      else
                                        const Icon(Icons.check_circle_outline),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(habit.title)),
                                      if (_compoundHabitIds.contains(habit.id))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF9F0A).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'COMPOUND',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF9F0A),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: habit.description.isNotEmpty
                                      ? Text(habit.description)
                                      : null,
                                  trailing: widget.onHabitSelected != null
                                      ? IconButton(
                                          icon: const Icon(Icons.add_circle),
                                          onPressed: () => widget.onHabitSelected!(habit),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _showEditHabitDialog(habit),
                                        ),
                                  onTap: widget.onHabitSelected != null
                                      ? () => widget.onHabitSelected!(habit)
                                      : () => _showEditHabitDialog(habit),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

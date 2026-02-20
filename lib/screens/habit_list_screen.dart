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
  List<Category> _availableCategories = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedCategory; // null means "All"

  List<String> get _categories {
    final cats = _habits.map((h) => h.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<Habit> get _filteredHabits {
    if (_selectedCategory == null) return _habits;
    return _habits.where((h) => h.category == _selectedCategory).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _loadAvailableCategories();
  }

  Future<void> _loadAvailableCategories() async {
    try {
      final categories = await ApiService.getCategoriesForUser(_currentUserId);
      setState(() {
        _availableCategories = categories;
      });
    } catch (e) {
      // Categories are optional, habit list still works
    }
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

  void _showAddHabitDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconController = TextEditingController();
    String? selectedCategoryName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                _buildCategoryDropdown(
                  selectedCategoryName,
                  (value) => setDialogState(() => selectedCategoryName = value),
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
                if (titleController.text.isEmpty || selectedCategoryName == null) {
                  return;
                }
                try {
                  await ApiService.createHabit(
                    title: titleController.text,
                    category: selectedCategoryName!,
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
      ),
    );
  }

  Widget _buildCategoryDropdown(String? selectedValue, ValueChanged<String?> onChanged) {
    final platformCats = _availableCategories.where((c) => c.type == 'platform').toList();
    final userCats = _availableCategories.where((c) => c.type == 'user').toList();

    final items = <DropdownMenuItem<String>>[];

    if (platformCats.isNotEmpty) {
      items.add(const DropdownMenuItem<String>(
        enabled: false,
        value: null,
        child: Text('--- Platform ---', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ));
      for (final cat in platformCats) {
        items.add(DropdownMenuItem<String>(value: cat.name, child: Text(cat.name)));
      }
    }

    if (userCats.isNotEmpty) {
      items.add(const DropdownMenuItem<String>(
        enabled: false,
        value: null,
        child: Text('--- Personal ---', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ));
      for (final cat in userCats) {
        items.add(DropdownMenuItem<String>(value: cat.name, child: Text(cat.name)));
      }
    }

    items.add(const DropdownMenuItem<String>(
      value: '__add_new__',
      child: Text('+ Add new category...', style: TextStyle(color: Color(0xFF58A6FF))),
    ));

    return DropdownButtonFormField<String>(
      value: selectedValue,
      decoration: const InputDecoration(labelText: 'Category'),
      items: items,
      onChanged: (value) {
        if (value == '__add_new__') {
          _showNewCategoryDialog((newName) {
            onChanged(newName);
          });
        } else {
          onChanged(value);
        }
      },
    );
  }

  void _showNewCategoryDialog(ValueChanged<String> onCreated) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('New Personal Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                final cat = await ApiService.createUserCategory(
                  controller.text.trim(),
                  _currentUserId,
                );
                setState(() {
                  _availableCategories.add(cat);
                });
                if (context.mounted) Navigator.pop(context);
                onCreated(cat.name);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditHabitDialog(Habit habit) {
    final titleController = TextEditingController(text: habit.title);
    final descriptionController = TextEditingController(text: habit.description);
    final iconController = TextEditingController(text: habit.icon);
    String? selectedCategoryName = habit.category;

    // If habit's current category isn't in the available list, keep it as selected anyway
    final knownNames = _availableCategories.map((c) => c.name).toSet();
    if (!knownNames.contains(selectedCategoryName)) {
      selectedCategoryName = null;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                _buildCategoryDropdown(
                  selectedCategoryName,
                  (value) => setDialogState(() => selectedCategoryName = value),
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
                    'category': selectedCategoryName ?? habit.category,
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
          // Category filter chips
          if (_habits.isNotEmpty && _categories.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // "All" chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          'All',
                          style: TextStyle(
                            color: _selectedCategory == null ? Colors.white : Colors.grey.shade300,
                            fontWeight: _selectedCategory == null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        selected: _selectedCategory == null,
                        onSelected: (_) => setState(() => _selectedCategory = null),
                        backgroundColor: Colors.grey.shade800,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _selectedCategory == null 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    // Category chips
                    ..._categories.map((category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          category,
                          style: TextStyle(
                            color: _selectedCategory == category ? Colors.white : Colors.grey.shade300,
                            fontWeight: _selectedCategory == category ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        selected: _selectedCategory == category,
                        onSelected: (_) => setState(() => _selectedCategory = category),
                        backgroundColor: Colors.grey.shade800,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _selectedCategory == category 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
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
                    : _filteredHabits.isEmpty
                        ? Center(
                            child: Text(_selectedCategory != null 
                              ? 'No habits in this category' 
                              : 'No habits yet. Add one!'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredHabits.length,
                            itemBuilder: (context, index) {
                              final habit = _filteredHabits[index];
                              return Card(
                                key: ValueKey(habit.id),
                                child: ListTile(
                                  leading: habit.icon.isNotEmpty
                                      ? Text(
                                          habit.icon,
                                          style: const TextStyle(fontSize: 24),
                                        )
                                      : const Icon(Icons.check_circle_outline),
                                  title: Text(habit.title),
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

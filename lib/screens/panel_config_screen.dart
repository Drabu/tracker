import 'package:flutter/material.dart';
import '../models/models.dart';

class PanelConfigScreen extends StatefulWidget {
  const PanelConfigScreen({super.key});

  @override
  State<PanelConfigScreen> createState() => _PanelConfigScreenState();
}

class _PanelConfigScreenState extends State<PanelConfigScreen> {
  List<Panel> _panels = [];
  bool _isLoading = false;

  static const List<String> panelTypes = [
    'habits',
    'points_summary',
    'category_breakdown',
    'streak',
    'daily_goal',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadPanels();
  }

  Future<void> _loadPanels() async {
    setState(() => _isLoading = true);
    // TODO: Load from API when backend is ready
    // For now, use demo data
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _panels = [
        Panel(
          id: '1',
          name: 'Points Summary',
          type: 'points_summary',
          order: 0,
          isVisible: true,
        ),
        Panel(
          id: '2',
          name: 'Category Breakdown',
          type: 'category_breakdown',
          order: 1,
          isVisible: true,
        ),
        Panel(
          id: '3',
          name: 'Daily Streak',
          type: 'streak',
          order: 2,
          isVisible: false,
        ),
      ];
      _isLoading = false;
    });
  }

  void _showAddPanelDialog() {
    final nameController = TextEditingController();
    String selectedType = panelTypes.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Panel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Panel Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Panel Type'),
                items: panelTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_formatTypeName(type)),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
            ],
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
                  _panels.add(Panel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: selectedType,
                    order: _panels.length,
                    isVisible: true,
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

  void _showEditPanelDialog(Panel panel, int index) {
    final nameController = TextEditingController(text: panel.name);
    String selectedType = panel.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Panel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Panel Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: panelTypes.contains(selectedType) ? selectedType : panelTypes.first,
                decoration: const InputDecoration(labelText: 'Panel Type'),
                items: panelTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_formatTypeName(type)),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _panels.removeAt(index));
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
                  _panels[index] = panel.copyWith(
                    name: nameController.text,
                    type: selectedType,
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

  String _formatTypeName(String type) {
    return type.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'habits':
        return Icons.check_circle_outline;
      case 'points_summary':
        return Icons.score;
      case 'category_breakdown':
        return Icons.pie_chart;
      case 'streak':
        return Icons.local_fire_department;
      case 'daily_goal':
        return Icons.flag;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Panels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPanels,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPanelDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _panels.isEmpty
              ? const Center(child: Text('No panels configured. Add one!'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _panels.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final panel = _panels.removeAt(oldIndex);
                      _panels.insert(newIndex, panel);
                      for (int i = 0; i < _panels.length; i++) {
                        _panels[i] = _panels[i].copyWith(order: i);
                      }
                    });
                  },
                  itemBuilder: (context, index) {
                    final panel = _panels[index];
                    return Card(
                      key: ValueKey(panel.id),
                      child: ListTile(
                        leading: Icon(_getTypeIcon(panel.type)),
                        title: Text(panel.name),
                        subtitle: Text(_formatTypeName(panel.type)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: panel.isVisible,
                              onChanged: (value) {
                                setState(() {
                                  _panels[index] = panel.copyWith(isVisible: value);
                                });
                              },
                            ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                        onTap: () => _showEditPanelDialog(panel, index),
                      ),
                    );
                  },
                ),
    );
  }
}

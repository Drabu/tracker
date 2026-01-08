import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/clock_time_picker.dart';
import '../widgets/calendar_timeline.dart';
import 'habit_list_screen.dart';

class TimelineScreen extends StatefulWidget {
  final String userId;
  
  const TimelineScreen({super.key, required this.userId});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Event> _entries = [];
  Map<String, Habit> _habitsMap = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  static const int maxPoints = 100;
  static const int minDurationMinutes = 10;
  static const int maxDurationMinutes = 12 * 60; // 12 hours

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  int get _totalPoints => _entries.fold(0, (sum, e) => sum + e.points);
  int get _remainingPoints => maxPoints - _totalPoints;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final habits = await ApiService.getHabits();
      _habitsMap = {for (var h in habits) h.id: h};

      final dateStr = _formatDate(_selectedDate);
      final timeline = await ApiService.getTimelineByDate(widget.userId, dateStr);
      
      setState(() {
        _entries = timeline?.entries ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveTimeline() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.saveTimeline(
        userId: widget.userId,
        date: _formatDate(_selectedDate),
        entries: _entries,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _autoSave() {
    _saveTimeline();
  }

  void _showDuplicateToDateDialog() async {
    final targetDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.add(const Duration(days: 1)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (targetDate == null || !mounted) return;
    
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to duplicate')),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Timeline'),
        content: Text(
          'Copy ${_entries.length} entries from ${_formatDate(_selectedDate)} to ${_formatDate(targetDate)}?\n\nThis will replace any existing entries on that day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;
      var index = 0;
      final duplicatedEntries = _entries.map((e) {
        final entryId = '${baseTimestamp}_${index++}_${e.habitId}_${e.startMinutes}';
        return Event(
          id: entryId,
          habit: e.habit,
          startMinutes: e.startMinutes,
          durationMinutes: e.durationMinutes,
          points: e.points,
        );
      }).toList();
      
      await ApiService.saveTimeline(
        userId: widget.userId,
        date: _formatDate(targetDate),
        entries: duplicatedEntries,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Timeline duplicated to ${_formatDate(targetDate)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error duplicating: $e')),
        );
      }
    }
  }

  void _showClearTimelineDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Timeline'),
        content: Text(
          'Delete all ${_entries.length} entries from ${_formatDate(_selectedDate)}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.clearTimelineEntries(
        userId: widget.userId,
        date: _formatDate(_selectedDate),
      );
      setState(() => _entries = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timeline cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing timeline: $e')),
        );
      }
    }
  }

  void _addHabitToTimeline(Habit habit) {
    final nextMinutes = _findNextAvailableSlot();
    if (nextMinutes >= 24 * 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available time slots')),
      );
      return;
    }

    _showAddEntryDialog(habit, nextMinutes);
  }

  int _findNextAvailableSlot() {
    final occupied = <int>{};
    for (var entry in _entries) {
      for (int m = entry.startMinutes; m < entry.endMinutes; m++) {
        occupied.add(m);
      }
    }
    for (int m = 0; m < 24 * 60; m += 5) {
      if (!occupied.contains(m)) return m;
    }
    return 24 * 60;
  }

  void _showAddEntryDialog(Habit habit, int startMinutes) {
    int points = 0;
    int startHour = startMinutes ~/ 60;
    int startMinute = startMinutes % 60;
    int endHour = (startMinutes + 30) ~/ 60;
    int endMinute = (startMinutes + 30) % 60;
    if (endHour >= 24) {
      endHour = 23;
      endMinute = 55;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final duration = (endHour * 60 + endMinute) - (startHour * 60 + startMinute);
          final isValidDuration = duration >= minDurationMinutes && duration <= maxDurationMinutes;
          
          return AlertDialog(
            title: Text('Add ${habit.title}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DualClockTimePicker(
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                    onStartTimeChanged: (time) {
                      setDialogState(() {
                        startHour = time.hour;
                        startMinute = (time.minute ~/ 5) * 5;
                      });
                    },
                    onEndTimeChanged: (time) {
                      setDialogState(() {
                        endHour = time.hour;
                        endMinute = (time.minute ~/ 5) * 5;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isValidDuration ? Colors.grey.shade800 : Colors.red.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: isValidDuration ? Colors.grey.shade400 : Colors.red.shade200,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          duration > 0 ? _formatDuration(duration) : 'Invalid time range',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isValidDuration ? Colors.white : Colors.red.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Points: '),
                      Expanded(
                        child: Slider(
                          value: points.toDouble(),
                          min: 0,
                          max: _remainingPoints.toDouble().clamp(1, 50),
                          divisions: _remainingPoints.clamp(1, 50),
                          label: '$points pts',
                          onChanged: (v) => setDialogState(() => points = v.round()),
                        ),
                      ),
                      Text('$points pts'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Remaining: ${_remainingPoints - points} / $maxPoints',
                    style: TextStyle(
                      color: _remainingPoints - points < 0 ? Colors.red : Colors.grey,
                    ),
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
                onPressed: points <= _remainingPoints && isValidDuration
                    ? () {
                        final entryStartMinutes = startHour * 60 + startMinute;
                        setState(() {
                          _entries.add(Event(
                            id: '${DateTime.now().millisecondsSinceEpoch}_${habit.id}_$entryStartMinutes',
                            habit: habit,
                            startMinutes: entryStartMinutes,
                            durationMinutes: duration,
                            points: points,
                          ));
                          _entries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
                        });
                        _autoSave();
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  void _showEditEntryDialog(Event entry, int index) {
    int points = entry.points;
    int startHour = entry.startHour;
    int startMinute = entry.startMinute;
    int endHour = entry.endMinutes ~/ 60;
    int endMinute = entry.endMinutes % 60;
    final maxAddablePoints = _remainingPoints + entry.points;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final duration = (endHour * 60 + endMinute) - (startHour * 60 + startMinute);
          final isValidDuration = duration >= minDurationMinutes && duration <= maxDurationMinutes;
          
          return AlertDialog(
            title: Text('Edit ${_habitsMap[entry.habitId]?.title ?? 'Entry'}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DualClockTimePicker(
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                    onStartTimeChanged: (time) {
                      setDialogState(() {
                        startHour = time.hour;
                        startMinute = (time.minute ~/ 5) * 5;
                      });
                    },
                    onEndTimeChanged: (time) {
                      setDialogState(() {
                        endHour = time.hour;
                        endMinute = (time.minute ~/ 5) * 5;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isValidDuration ? Colors.grey.shade800 : Colors.red.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: isValidDuration ? Colors.grey.shade400 : Colors.red.shade200,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          duration > 0 ? _formatDuration(duration) : 'Invalid time range',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isValidDuration ? Colors.white : Colors.red.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Points: '),
                      Expanded(
                        child: Slider(
                          value: points.toDouble(),
                          min: 0,
                          max: maxAddablePoints.toDouble().clamp(1, 50),
                          divisions: maxAddablePoints.clamp(1, 50),
                          label: '$points pts',
                          onChanged: (v) => setDialogState(() => points = v.round()),
                        ),
                      ),
                      Text('$points pts'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _entries.removeAt(index));
                  _autoSave();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValidDuration
                    ? () {
                        setState(() {
                          _entries[index] = entry.copyWith(
                            startMinutes: startHour * 60 + startMinute,
                            durationMinutes: duration,
                            points: points,
                          );
                          _entries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
                        });
                        _autoSave();
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddHabitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => HabitListScreen(
          onHabitSelected: (habit) {
            Navigator.pop(context);
            _addHabitToTimeline(habit);
          },
        ),
      ),
    );
  }

  void _showHabitPickerForTimeRange(int startMinutes, int endMinutes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => HabitListScreen(
          onHabitSelected: (habit) {
            Navigator.pop(context);
            _addEntryWithTimeRange(habit, startMinutes, endMinutes);
          },
        ),
      ),
    );
  }

  void _addEntryWithTimeRange(Habit habit, int startMinutes, int endMinutes) {
    final duration = endMinutes - startMinutes;
    int points = 0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Add ${habit.title}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (habit.icon.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(habit.icon, style: const TextStyle(fontSize: 24)),
                        ),
                      Column(
                        children: [
                          Text(
                            '${_formatMinutesToTime(startMinutes)} - ${_formatMinutesToTime(endMinutes)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Points: '),
                    Expanded(
                      child: Slider(
                        value: points.toDouble(),
                        min: 0,
                        max: _remainingPoints.toDouble().clamp(1, 50),
                        divisions: _remainingPoints.clamp(1, 50),
                        label: '$points pts',
                        onChanged: (v) => setDialogState(() => points = v.round()),
                      ),
                    ),
                    Text('$points pts'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Remaining: ${_remainingPoints - points} / $maxPoints',
                  style: TextStyle(
                    color: _remainingPoints - points < 0 ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: points <= _remainingPoints
                    ? () {
                        setState(() {
                          _entries.add(Event(
                            id: '${DateTime.now().millisecondsSinceEpoch}_${habit.id}_$startMinutes',
                            habit: habit,
                            startMinutes: startMinutes,
                            durationMinutes: duration,
                            points: points,
                          ));
                          _entries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
                        });
                        _autoSave();
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatMinutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all entries',
            onPressed: _entries.isEmpty ? null : _showClearTimelineDialog,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Duplicate to another day',
            onPressed: _showDuplicateToDateDialog,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
                _loadData();
              }
            },
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveTimeline,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHabitSheet,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPointsIndicator(),
                Expanded(child: _buildTimeline()),
              ],
            ),
    );
  }

  Widget _buildPointsIndicator() {
    final progress = _totalPoints / maxPoints;
    final isOverLimit = _totalPoints > maxPoints;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(_selectedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '$_totalPoints / $maxPoints points',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOverLimit ? Colors.red : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.grey.shade800,
              color: isOverLimit ? Colors.red : Theme.of(context).colorScheme.primary,
            ),
          ),
          if (isOverLimit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Exceeded by ${_totalPoints - maxPoints} points!',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return CalendarTimeline(
      entries: _entries,
      habitsMap: _habitsMap,
      onDragCreate: (startMinutes, endMinutes) {
        _showHabitPickerForTimeRange(startMinutes, endMinutes);
      },
      onEntryTap: (entry, index) {
        _showEditEntryDialog(entry, index);
      },
      onEntryResize: (index, newStartMinutes, newEndMinutes) {
        setState(() {
          final entry = _entries[index];
          _entries[index] = entry.copyWith(
            startMinutes: newStartMinutes,
            durationMinutes: newEndMinutes - newStartMinutes,
          );
          _entries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        });
        _autoSave();
      },
      onEntryMove: (index, newStartMinutes, newEndMinutes) {
        setState(() {
          final entry = _entries[index];
          _entries[index] = entry.copyWith(
            startMinutes: newStartMinutes,
            durationMinutes: newEndMinutes - newStartMinutes,
          );
          _entries.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        });
        _autoSave();
      },
    );
  }
}

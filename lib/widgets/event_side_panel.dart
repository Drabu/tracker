import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// An Apple Calendar-style sliding side panel for editing events.
/// Matches the native macOS/iOS Calendar event editor design.
class EventSidePanel extends StatefulWidget {
  final Event entry;
  final int entryIndex;
  final Map<String, Habit> habitsMap;
  final int remainingPoints;
  final int minDurationMinutes;
  final int maxDurationMinutes;
  final VoidCallback onClose;
  final Function(Event updatedEntry) onSave;
  final VoidCallback onDelete;
  final Function(Habit? habit) onSelectHabit;

  const EventSidePanel({
    super.key,
    required this.entry,
    required this.entryIndex,
    required this.habitsMap,
    required this.remainingPoints,
    required this.minDurationMinutes,
    required this.maxDurationMinutes,
    required this.onClose,
    required this.onSave,
    required this.onDelete,
    required this.onSelectHabit,
  });

  @override
  State<EventSidePanel> createState() => _EventSidePanelState();
}

class _EventSidePanelState extends State<EventSidePanel> {
  late int _points;
  late int _startHour;
  late int _startMinute;
  late int _endHour;
  late int _endMinute;
  late Habit? _selectedHabit;
  late TextEditingController _notesController;
  
  final FocusNode _panelFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeFromEntry(widget.entry);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _panelFocusNode.requestFocus();
    });
  }

  void _initializeFromEntry(Event entry) {
    _points = entry.points;
    _startHour = entry.startHour;
    _startMinute = entry.startMinute;
    _endHour = entry.endMinutes ~/ 60;
    _endMinute = entry.endMinutes % 60;
    _selectedHabit = widget.habitsMap[entry.habitId];
    _notesController = TextEditingController(text: entry.notes ?? '');
  }

  @override
  void didUpdateWidget(EventSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.habitId != oldWidget.entry.habitId) {
      setState(() {
        _selectedHabit = widget.habitsMap[widget.entry.habitId];
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  int get _duration => (_endHour * 60 + _endMinute) - (_startHour * 60 + _startMinute);
  
  bool get _isValidDuration => 
      _duration >= widget.minDurationMinutes && 
      _duration <= widget.maxDurationMinutes;

  int get _maxAddablePoints => widget.remainingPoints + widget.entry.points;

  Color get _habitColor {
    if (_selectedHabit == null) return const Color(0xFF8E8E93);
    switch (_selectedHabit!.category.toLowerCase()) {
      case 'health': return const Color(0xFF30D158);
      case 'work': return const Color(0xFFBF5AF2);
      case 'personal': return const Color(0xFF0A84FF);
      case 'fitness': return const Color(0xFFFF9F0A);
      case 'learning': return const Color(0xFF64D2FF);
      default: return const Color(0xFF8E8E93);
    }
  }

  void _closePanel() {
    widget.onClose();
  }

  void _saveChanges() {
    if (!_isValidDuration || _selectedHabit == null) return;
    
    HapticFeedback.lightImpact();
    
    final updatedEntry = widget.entry.copyWith(
      habit: _selectedHabit,
      startMinutes: _startHour * 60 + _startMinute,
      durationMinutes: _duration,
      points: _points,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );
    
    widget.onSave(updatedEntry);
    _closePanel();
  }

  void _deleteEntry() {
    HapticFeedback.mediumImpact();
    widget.onDelete();
    _closePanel();
  }

  String _formatTime(int hour, int minute) {
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour < 12 ? 'AM' : 'PM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _panelFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && 
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closePanel();
        }
      },
      child: _buildPanel(),
    );
  }

  Widget _buildPanel() {
    return Container(
      decoration: BoxDecoration(
        // Clean dark background matching Apple Calendar
        color: const Color(0xFF1C1C1E),
        border: Border(
          left: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildTitleRow(),
                    const SizedBox(height: 24),
                    _buildDateTimeRow(),
                    _buildDivider(),
                    _buildPointsRow(),
                    _buildDivider(),
                    _buildNotesRow(),
                    _buildDivider(),
                    const SizedBox(height: 24),
                    _buildDeleteButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canSave = _isValidDuration && _selectedHabit != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _closePanel,
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 17,
                color: _habitColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: canSave ? _saveChanges : null,
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 17,
                color: canSave ? _habitColor : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Habit title
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onSelectHabit(_selectedHabit);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_selectedHabit?.icon.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _selectedHabit!.icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _selectedHabit?.title ?? 'Select Habit',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: _selectedHabit != null 
                              ? Colors.white 
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Category badge
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onSelectHabit(_selectedHabit);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _habitColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedHabit?.category ?? 'Category',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderRow(String text, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 4,
              color: iconColor ?? Colors.white.withValues(alpha: 0.4),
            ),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow() {
    return Column(
      children: [
        // Date and time row
        Row(
          children: [
            // Date
            Text(
              _formatDate(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            // Time range
            GestureDetector(
              onTap: () => _showTimePicker(isStart: true),
              child: Text(
                _formatTime(_startHour, _startMinute),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: _habitColor,
                ),
              ),
            ),
            Text(
              ' to ',
              style: TextStyle(
                fontSize: 17,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            GestureDetector(
              onTap: () => _showTimePicker(isStart: false),
              child: Text(
                _formatTime(_endHour, _endMinute),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: _habitColor,
                ),
              ),
            ),
          ],
        ),
        // Duration indicator
        if (!_isValidDuration)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: const Color(0xFFFF453A).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Invalid duration',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFFFF453A).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showTimePicker({required bool isStart}) async {
    final initialTime = TimeOfDay(
      hour: isStart ? _startHour : _endHour,
      minute: isStart ? _startMinute : _endMinute,
    );
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _habitColor,
              surface: const Color(0xFF2C2C2E),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() {
        if (isStart) {
          _startHour = picked.hour;
          _startMinute = (picked.minute ~/ 5) * 5;
        } else {
          _endHour = picked.hour;
          _endMinute = (picked.minute ~/ 5) * 5;
        }
      });
    }
  }

  Widget _buildPointsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.stars_rounded,
                size: 18,
                color: const Color(0xFFFFD60A).withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Text(
                'Points',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              Text(
                '$_points pts',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFFFD60A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFFFD60A),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFFFFD60A).withValues(alpha: 0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _points.toDouble(),
              min: 0,
              max: _maxAddablePoints.toDouble().clamp(1, 50),
              divisions: _maxAddablePoints.clamp(1, 50),
              onChanged: (v) {
                setState(() => _points = v.round());
                HapticFeedback.selectionClick();
              },
            ),
          ),
          Text(
            'Available: $_maxAddablePoints points',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _notesController,
            maxLines: null,
            minLines: 1,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            decoration: InputDecoration(
              hintText: 'Add Notes',
              hintStyle: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.35),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildDeleteButton() {
    return Center(
      child: GestureDetector(
        onTap: _deleteEntry,
        child: Text(
          'Delete Event',
          style: TextStyle(
            fontSize: 17,
            color: const Color(0xFFFF453A).withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

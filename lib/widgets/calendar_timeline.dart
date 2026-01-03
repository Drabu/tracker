import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

class CalendarTimeline extends StatefulWidget {
  final List<TimelineEntry> entries;
  final Map<String, Habit> habitsMap;
  final Function(int startMinutes, int endMinutes) onDragCreate;
  final Function(TimelineEntry entry, int index) onEntryTap;
  final Function(int index, int newStartMinutes, int newEndMinutes)? onEntryResize;
  final Function(int index, int newStartMinutes, int newEndMinutes)? onEntryMove;
  final int startHour;
  final int endHour;

  const CalendarTimeline({
    super.key,
    required this.entries,
    required this.habitsMap,
    required this.onDragCreate,
    required this.onEntryTap,
    this.onEntryResize,
    this.onEntryMove,
    this.startHour = 0,
    this.endHour = 24,
  });

  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

enum TimeSection {
  morning(5 * 60, 12 * 60, 'Morning', Icons.wb_sunny_outlined),
  afternoon(12 * 60, 17 * 60, 'Afternoon', Icons.wb_sunny),
  evening(17 * 60, 24 * 60, 'Evening', Icons.nightlight_outlined);

  final int startMinutes;
  final int endMinutes;
  final String label;
  final IconData icon;

  const TimeSection(this.startMinutes, this.endMinutes, this.label, this.icon);

  static TimeSection getCurrentSection() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    if (currentMinutes >= evening.startMinutes) return evening;
    if (currentMinutes >= afternoon.startMinutes) return afternoon;
    return morning;
  }

  bool containsTime(int minutes) {
    return minutes >= startMinutes && minutes < endMinutes;
  }
}

class _CalendarTimelineState extends State<CalendarTimeline> {
  static const double hourHeight = 150.0;
  static const double timeGutterWidth = 56.0;
  static const double nowIndicatorWidth = 8.0;
  static const double resizeHandleHeight = 12.0;
  static const double sectionHeaderHeight = 48.0;
  
  final ScrollController _scrollController = ScrollController();
  
  // Section collapsed state
  late Map<TimeSection, bool> _sectionExpanded;
  
  // Drag state for creating new entries
  bool _isDragging = false;
  int? _dragStartMinutes;
  int? _dragEndMinutes;
  
  // Resize state
  bool _isResizing = false;
  int? _resizingIndex;
  bool _resizingTop = false;
  int? _resizeStartMinutes;
  int? _resizeEndMinutes;
  
  // Hover state for resize handles
  int? _hoveredEntryIndex;
  bool _hoveringTop = false;
  bool _hoveringBottom = false;
  
  // Move/drag state for moving entries
  bool _isMoving = false;
  int? _movingIndex;
  int? _moveStartMinutes;
  int? _moveEndMinutes;
  int? _moveDragStartY;

  @override
  void initState() {
    super.initState();
    final currentSection = TimeSection.getCurrentSection();
    _sectionExpanded = {
      TimeSection.morning: currentSection == TimeSection.morning,
      TimeSection.afternoon: currentSection == TimeSection.afternoon,
      TimeSection.evening: currentSection == TimeSection.evening,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentSection());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentSection() {
    if (!_scrollController.hasClients) return;
    
    final currentSection = TimeSection.getCurrentSection();
    double offset = 0;
    
    for (final section in TimeSection.values) {
      if (section == currentSection) {
        final now = DateTime.now();
        final currentMinutes = now.hour * 60 + now.minute;
        final sectionOffset = (currentMinutes - section.startMinutes) / 60 * hourHeight;
        offset += sectionOffset.clamp(0, double.infinity);
        break;
      }
      if (_sectionExpanded[section] == true) {
        final sectionHours = (section.endMinutes - section.startMinutes) / 60;
        offset += sectionHours * hourHeight;
      }
      offset += sectionHeaderHeight;
    }
    
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  int _getMinutesFromY(double y, TimeSection section) {
    final sectionRelativeY = y;
    final totalMinutes = section.startMinutes + (sectionRelativeY / hourHeight * 60).round();
    return ((totalMinutes / 5).round() * 5).clamp(section.startMinutes, section.endMinutes - 5);
  }

  void _toggleSection(TimeSection section) {
    HapticFeedback.lightImpact();
    setState(() {
      _sectionExpanded[section] = !(_sectionExpanded[section] ?? false);
    });
  }

  List<TimelineEntry> _getEntriesForSection(TimeSection section) {
    return widget.entries.where((e) {
      return e.startMinutes >= section.startMinutes && e.startMinutes < section.endMinutes;
    }).toList();
  }

  int _getPointsForSection(TimeSection section) {
    return _getEntriesForSection(section).fold(0, (sum, e) => sum + e.points);
  }

  void _handleDragStart(DragStartDetails details, TimeSection section, double sectionStartY) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset - sectionStartY;
    
    final minutes = _getMinutesFromY(y, section);
    
    for (int i = 0; i < widget.entries.length; i++) {
      final entry = widget.entries[i];
      if (minutes >= entry.startMinutes && minutes < entry.endMinutes) {
        return;
      }
    }
    
    HapticFeedback.lightImpact();
    setState(() {
      _isDragging = true;
      _dragStartMinutes = minutes;
      _dragEndMinutes = minutes + 15;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, TimeSection section, double sectionStartY) {
    if (!_isDragging || _dragStartMinutes == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset - sectionStartY;
    
    final minutes = _getMinutesFromY(y, section);
    
    setState(() {
      _dragEndMinutes = minutes;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging || _dragStartMinutes == null || _dragEndMinutes == null) {
      _resetDrag();
      return;
    }
    
    int startMin = _dragStartMinutes!;
    int endMin = _dragEndMinutes!;
    
    if (endMin < startMin) {
      final temp = startMin;
      startMin = endMin;
      endMin = temp;
    }
    
    if (endMin - startMin < 10) {
      endMin = startMin + 15;
    }
    
    endMin = endMin.clamp(0, 24 * 60);
    
    HapticFeedback.mediumImpact();
    widget.onDragCreate(startMin, endMin);
    _resetDrag();
  }

  void _resetDrag() {
    setState(() {
      _isDragging = false;
      _dragStartMinutes = null;
      _dragEndMinutes = null;
    });
  }

  void _handleResizeStart(int index, bool isTop, double globalY) {
    final entry = widget.entries[index];
    HapticFeedback.lightImpact();
    setState(() {
      _isResizing = true;
      _resizingIndex = index;
      _resizingTop = isTop;
      _resizeStartMinutes = entry.startMinutes;
      _resizeEndMinutes = entry.endMinutes;
    });
  }

  void _handleResizeUpdate(DragUpdateDetails details, TimeSection section, double sectionStartY) {
    if (!_isResizing || _resizingIndex == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset - sectionStartY;
    final minutes = _getMinutesFromY(y, section);
    
    setState(() {
      if (_resizingTop) {
        _resizeStartMinutes = minutes.clamp(0, (_resizeEndMinutes ?? 24 * 60) - 10);
      } else {
        _resizeEndMinutes = minutes.clamp((_resizeStartMinutes ?? 0) + 10, 24 * 60);
      }
    });
  }

  void _handleResizeEnd() {
    if (!_isResizing || _resizingIndex == null) {
      _resetResize();
      return;
    }
    
    final index = _resizingIndex!;
    final startMin = _resizeStartMinutes!;
    final endMin = _resizeEndMinutes!;
    
    HapticFeedback.mediumImpact();
    widget.onEntryResize?.call(index, startMin, endMin);
    _resetResize();
  }

  void _resetResize() {
    setState(() {
      _isResizing = false;
      _resizingIndex = null;
      _resizeStartMinutes = null;
      _resizeEndMinutes = null;
    });
  }

  void _handleMoveStart(int index, double globalY) {
    final entry = widget.entries[index];
    HapticFeedback.lightImpact();
    setState(() {
      _isMoving = true;
      _movingIndex = index;
      _moveStartMinutes = entry.startMinutes;
      _moveEndMinutes = entry.endMinutes;
      
      final RenderBox box = context.findRenderObject() as RenderBox;
      final localY = box.globalToLocal(Offset(0, globalY)).dy + _scrollController.offset;
      _moveDragStartY = localY.round();
    });
  }

  void _handleMoveUpdate(DragUpdateDetails details) {
    if (!_isMoving || _movingIndex == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final currentY = localPosition.dy + _scrollController.offset;
    
    final entry = widget.entries[_movingIndex!];
    final duration = entry.endMinutes - entry.startMinutes;
    
    final deltaY = currentY - _moveDragStartY!;
    final deltaMinutes = ((deltaY / hourHeight) * 60).round();
    final snappedDelta = (deltaMinutes / 5).round() * 5;
    
    var newStart = entry.startMinutes + snappedDelta;
    var newEnd = entry.endMinutes + snappedDelta;
    
    if (newStart < 0) {
      newStart = 0;
      newEnd = duration;
    }
    if (newEnd > 24 * 60) {
      newEnd = 24 * 60;
      newStart = newEnd - duration;
    }
    
    setState(() {
      _moveStartMinutes = newStart;
      _moveEndMinutes = newEnd;
    });
  }

  void _handleMoveEnd() {
    if (!_isMoving || _movingIndex == null) {
      _resetMove();
      return;
    }
    
    final index = _movingIndex!;
    final startMin = _moveStartMinutes!;
    final endMin = _moveEndMinutes!;
    
    HapticFeedback.mediumImpact();
    widget.onEntryMove?.call(index, startMin, endMin);
    _resetMove();
  }

  void _resetMove() {
    setState(() {
      _isMoving = false;
      _movingIndex = null;
      _moveStartMinutes = null;
      _moveEndMinutes = null;
      _moveDragStartY = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: TimeSection.values.length,
      itemBuilder: (context, index) {
        final section = TimeSection.values[index];
        return _buildSection(section);
      },
    );
  }

  Widget _buildSection(TimeSection section) {
    final isExpanded = _sectionExpanded[section] ?? false;
    final entries = _getEntriesForSection(section);
    final sectionPoints = _getPointsForSection(section);
    final currentSection = TimeSection.getCurrentSection();
    final isCurrent = section == currentSection;
    
    final sectionHours = (section.endMinutes - section.startMinutes) / 60;
    final sectionHeight = sectionHours * hourHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        InkWell(
          onTap: () => _toggleSection(section),
          child: Container(
            height: sectionHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isCurrent 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade900,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 20,
                  color: isCurrent 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.label,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isCurrent 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.white,
                        ),
                      ),
                      Text(
                        '${_formatMinutes(section.startMinutes)} - ${_formatMinutes(section.endMinutes)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entries.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entries.length} items • $sectionPoints pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Section content
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: _buildSectionContent(section, sectionHeight),
          crossFadeState: isExpanded 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildSectionContent(TimeSection section, double sectionHeight) {
    return GestureDetector(
      onLongPressStart: (details) {
        _handleDragStart(
          DragStartDetails(globalPosition: details.globalPosition),
          section,
          _getSectionStartY(section),
        );
      },
      onLongPressMoveUpdate: (details) {
        _handleDragUpdate(
          DragUpdateDetails(globalPosition: details.globalPosition, delta: Offset.zero),
          section,
          _getSectionStartY(section),
        );
      },
      onLongPressEnd: (details) {
        _handleDragEnd(DragEndDetails());
      },
      child: SizedBox(
        height: sectionHeight,
        child: Stack(
          children: [
            ..._buildHourLinesForSection(section),
            ..._buildEntriesForSection(section),
            if (section == TimeSection.getCurrentSection())
              _buildCurrentTimeIndicator(section),
            if (_isDragging && _dragStartMinutes != null && _dragEndMinutes != null)
              _buildDragSelection(section),
          ],
        ),
      ),
    );
  }

  double _getSectionStartY(TimeSection section) {
    double offset = 0;
    for (final s in TimeSection.values) {
      offset += sectionHeaderHeight;
      if (s == section) break;
      if (_sectionExpanded[s] == true) {
        final sectionHours = (s.endMinutes - s.startMinutes) / 60;
        offset += sectionHours * hourHeight;
      }
    }
    return offset;
  }

  List<Widget> _buildHourLinesForSection(TimeSection section) {
    final List<Widget> lines = [];
    final startHour = section.startMinutes ~/ 60;
    final endHour = section.endMinutes ~/ 60;
    
    for (int hour = startHour; hour <= endHour; hour++) {
      final y = (hour - startHour) * hourHeight;
      final isCurrentHour = DateTime.now().hour == hour;
      
      lines.add(
        Positioned(
          left: 0,
          top: y,
          right: 0,
          child: Row(
            children: [
              SizedBox(
                width: timeGutterWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    hour == 0 ? '12 AM' :
                    hour < 12 ? '$hour AM' :
                    hour == 12 ? '12 PM' :
                    '${hour - 12} PM',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentHour 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 0.5,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return lines;
  }

  Widget _buildCurrentTimeIndicator(TimeSection section) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final y = (currentMinutes - section.startMinutes) / 60 * hourHeight;
    
    if (y < 0 || y > (section.endMinutes - section.startMinutes) / 60 * hourHeight) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      left: timeGutterWidth - nowIndicatorWidth / 2,
      top: y - nowIndicatorWidth / 2,
      right: 0,
      child: Row(
        children: [
          Container(
            width: nowIndicatorWidth,
            height: nowIndicatorWidth,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEntriesForSection(TimeSection section) {
    final List<Widget> widgets = [];
    
    for (int index = 0; index < widget.entries.length; index++) {
      final entry = widget.entries[index];
      
      if (entry.startMinutes < section.startMinutes || entry.startMinutes >= section.endMinutes) {
        continue;
      }
      
      final habit = widget.habitsMap[entry.habitId];
      
      final isBeingResized = _isResizing && _resizingIndex == index;
      final isBeingMoved = _isMoving && _movingIndex == index;
      
      int displayStartMinutes;
      int displayEndMinutes;
      
      if (isBeingMoved) {
        displayStartMinutes = _moveStartMinutes!;
        displayEndMinutes = _moveEndMinutes!;
      } else if (isBeingResized) {
        displayStartMinutes = _resizeStartMinutes!;
        displayEndMinutes = _resizeEndMinutes!;
      } else {
        displayStartMinutes = entry.startMinutes;
        displayEndMinutes = entry.endMinutes;
      }
      
      final displayDuration = displayEndMinutes - displayStartMinutes;
      
      final startY = (displayStartMinutes - section.startMinutes) / 60 * hourHeight;
      final naturalHeight = displayDuration / 60 * hourHeight;
      final height = naturalHeight.clamp(10.0, double.infinity);
      
      final isHovered = _hoveredEntryIndex == index;
      final isActive = isBeingResized || isBeingMoved;
      final categoryColor = _getCategoryColor(habit?.category ?? '');
      
      widgets.add(
        Positioned(
          left: timeGutterWidth + 4,
          top: startY + 1,
          right: 8,
          height: height - 2,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredEntryIndex = index),
            onExit: (_) => setState(() {
              _hoveredEntryIndex = null;
              _hoveringTop = false;
              _hoveringBottom = false;
            }),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => widget.onEntryTap(entry, index),
                    onLongPressStart: (details) => _handleMoveStart(index, details.globalPosition.dy),
                    onLongPressMoveUpdate: (details) => _handleMoveUpdate(DragUpdateDetails(
                      globalPosition: details.globalPosition,
                      delta: Offset.zero,
                    )),
                    onLongPressEnd: (_) => _handleMoveEnd(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: isBeingMoved ? 0.7 : 0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive ? Colors.white : categoryColor,
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isBeingMoved ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: height < 30 ? 4 : 8, vertical: height < 30 ? 2 : 4),
                      child: height < 30
                          ? Row(
                              children: [
                                if (habit?.icon.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(habit!.icon, style: const TextStyle(fontSize: 12)),
                                  ),
                                Expanded(
                                  child: Text(
                                    habit?.title ?? entry.habitName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isActive 
                                      ? '${_formatMinutes(displayStartMinutes)}-${_formatMinutes(displayEndMinutes)}'
                                      : '${entry.startTimeFormatted}-${entry.endTimeFormatted}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${entry.points}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (habit?.icon.isNotEmpty == true)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text(habit!.icon, style: const TextStyle(fontSize: 14)),
                                      ),
                                    Expanded(
                                      child: Text(
                                        habit?.title ?? entry.habitName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${entry.points}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (height > 40)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      isActive 
                                          ? '${_formatMinutes(displayStartMinutes)} - ${_formatMinutes(displayEndMinutes)}'
                                          : '${entry.startTimeFormatted} - ${entry.endTimeFormatted}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
                
                // Top resize handle
                if (isHovered || isBeingResized)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -resizeHandleHeight / 2,
                    height: resizeHandleHeight,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeRow,
                      onEnter: (_) => setState(() => _hoveringTop = true),
                      onExit: (_) => setState(() => _hoveringTop = false),
                      child: GestureDetector(
                        onVerticalDragStart: (details) => _handleResizeStart(index, true, details.globalPosition.dy),
                        onVerticalDragUpdate: (details) => _handleResizeUpdate(details, section, _getSectionStartY(section)),
                        onVerticalDragEnd: (_) => _handleResizeEnd(),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _hoveringTop || (isBeingResized && _resizingTop) ? 48 : 32,
                            height: _hoveringTop || (isBeingResized && _resizingTop) ? 6 : 4,
                            decoration: BoxDecoration(
                              color: _hoveringTop || (isBeingResized && _resizingTop)
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Bottom resize handle
                if (isHovered || isBeingResized)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -resizeHandleHeight / 2,
                    height: resizeHandleHeight,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeRow,
                      onEnter: (_) => setState(() => _hoveringBottom = true),
                      onExit: (_) => setState(() => _hoveringBottom = false),
                      child: GestureDetector(
                        onVerticalDragStart: (details) => _handleResizeStart(index, false, details.globalPosition.dy),
                        onVerticalDragUpdate: (details) => _handleResizeUpdate(details, section, _getSectionStartY(section)),
                        onVerticalDragEnd: (_) => _handleResizeEnd(),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _hoveringBottom || (isBeingResized && !_resizingTop) ? 48 : 32,
                            height: _hoveringBottom || (isBeingResized && !_resizingTop) ? 6 : 4,
                            decoration: BoxDecoration(
                              color: _hoveringBottom || (isBeingResized && !_resizingTop)
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildDragSelection(TimeSection section) {
    int startMin = _dragStartMinutes!;
    int endMin = _dragEndMinutes!;
    
    if (startMin < section.startMinutes || startMin >= section.endMinutes) {
      return const SizedBox.shrink();
    }
    
    if (endMin < startMin) {
      final temp = startMin;
      startMin = endMin;
      endMin = temp;
    }
    
    final startY = (startMin - section.startMinutes) / 60 * hourHeight;
    final height = ((endMin - startMin) / 60 * hourHeight).clamp(15.0, double.infinity);
    
    return Positioned(
      left: timeGutterWidth + 4,
      top: startY,
      right: 8,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'New Entry',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (height > 40)
              Text(
                '${_formatMinutes(startMin)} - ${_formatMinutes(endMin)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  Color _getCategoryColor(String category) {
    final hash = category.hashCode;
    final colors = [
      const Color(0xFFFF453A),
      const Color(0xFF30D158),
      const Color(0xFFFF9F0A),
      const Color(0xFF00C7BE),
      const Color(0xFF5856D6),
      const Color(0xFF007AFF),
      const Color(0xFFAF52DE),
      const Color(0xFFFFD60A),
    ];
    return colors[hash.abs() % colors.length];
  }
}

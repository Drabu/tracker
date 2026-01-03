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

class _CalendarTimelineState extends State<CalendarTimeline> {
  static const double hourHeight = 150.0;
  static const double timeGutterWidth = 56.0;
  static const double nowIndicatorWidth = 8.0;
  static const double resizeHandleHeight = 12.0;
  
  final ScrollController _scrollController = ScrollController();
  
  // Drag state for creating new entries
  bool _isDragging = false;
  int? _dragStartMinutes;
  int? _dragEndMinutes;
  
  // Resize state
  bool _isResizing = false;
  int? _resizingIndex;
  bool _resizingTop = false; // true = resizing start time, false = resizing end time
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
  int? _moveDragStartY; // Y position when drag started
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final targetScroll = (currentMinutes / 60 - 2) * hourHeight;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetScroll.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  int _getMinutesFromY(double y) {
    final totalMinutes = (y / hourHeight * 60).round();
    // Snap to 5-minute intervals
    return ((totalMinutes / 5).round() * 5).clamp(0, 24 * 60 - 5);
  }

  void _handleDragStart(DragStartDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset;
    
    final minutes = _getMinutesFromY(y);
    
    // Check if we're tapping on an existing entry
    for (int i = 0; i < widget.entries.length; i++) {
      final entry = widget.entries[i];
      if (minutes >= entry.startMinutes && minutes < entry.endMinutes) {
        // Tapped on existing entry, don't start drag
        return;
      }
    }
    
    HapticFeedback.lightImpact();
    setState(() {
      _isDragging = true;
      _dragStartMinutes = minutes;
      _dragEndMinutes = minutes + 15; // Default 15 min duration
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _dragStartMinutes == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset;
    
    final minutes = _getMinutesFromY(y);
    
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
    
    // Ensure start is before end
    if (endMin < startMin) {
      final temp = startMin;
      startMin = endMin;
      endMin = temp;
    }
    
    // Minimum 10 minutes
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

  void _handleResizeUpdate(DragUpdateDetails details) {
    if (!_isResizing || _resizingIndex == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset;
    final minutes = _getMinutesFromY(y);
    
    setState(() {
      if (_resizingTop) {
        // Resizing start time - can't go past end time minus 10 min
        _resizeStartMinutes = minutes.clamp(0, (_resizeEndMinutes ?? 24 * 60) - 10);
      } else {
        // Resizing end time - can't go before start time plus 10 min
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
    
    // Calculate delta from drag start
    final deltaY = currentY - _moveDragStartY!;
    final deltaMinutes = ((deltaY / hourHeight) * 60).round();
    final snappedDelta = (deltaMinutes / 5).round() * 5;
    
    var newStart = entry.startMinutes + snappedDelta;
    var newEnd = entry.endMinutes + snappedDelta;
    
    // Clamp to valid range
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
    final totalHours = widget.endHour - widget.startHour;
    final totalHeight = totalHours * hourHeight;

    return GestureDetector(
      onLongPressStart: (details) {
        _handleDragStart(DragStartDetails(globalPosition: details.globalPosition));
      },
      onLongPressMoveUpdate: (details) {
        _handleDragUpdate(DragUpdateDetails(
          globalPosition: details.globalPosition,
          delta: Offset.zero,
        ));
      },
      onLongPressEnd: (details) {
        _handleDragEnd(DragEndDetails());
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          height: totalHeight,
          child: Stack(
            children: [
              // Hour grid lines and labels
              ..._buildHourLines(totalHours),
              
              // Existing entries
              ..._buildEntries(),
              
              // Current time indicator (on top of entries)
              _buildCurrentTimeIndicator(),
              
              // Drag selection overlay
              if (_isDragging && _dragStartMinutes != null && _dragEndMinutes != null)
                _buildDragSelection(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHourLines(int totalHours) {
    final List<Widget> lines = [];
    
    for (int i = 0; i <= totalHours; i++) {
      final hour = widget.startHour + i;
      final y = i * hourHeight;
      final isCurrentHour = DateTime.now().hour == hour;
      
      lines.add(
        Positioned(
          left: 0,
          top: y,
          right: 0,
          child: Row(
            children: [
              // Time label
              SizedBox(
                width: timeGutterWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 0),
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
              // Grid line
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

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final y = (currentMinutes - widget.startHour * 60) / 60 * hourHeight;
    
    if (y < 0 || y > (widget.endHour - widget.startHour) * hourHeight) {
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
            decoration: BoxDecoration(
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

  List<Widget> _buildEntries() {
    final List<Widget> widgets = [];
    
    for (int index = 0; index < widget.entries.length; index++) {
      final entry = widget.entries[index];
      final habit = widget.habitsMap[entry.habitId];
      
      // Use resize state if this entry is being resized
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
      
      final startY = (displayStartMinutes - widget.startHour * 60) / 60 * hourHeight;
      final naturalHeight = displayDuration / 60 * hourHeight;
      final height = naturalHeight.clamp(10.0, double.infinity);
      
      final isHovered = _hoveredEntryIndex == index;
      final isActive = isBeingResized || isBeingMoved;
      final categoryColor = _getCategoryColor(habit?.category ?? '');
      
      final tooltipMessage = '${habit?.title ?? entry.habitName}\n${entry.startTimeFormatted} - ${entry.endTimeFormatted}';
      
      widgets.add(
        Positioned(
          left: timeGutterWidth + 4,
          top: startY + 1,
          right: 8,
          height: height - 2,
          child: Tooltip(
            message: tooltipMessage,
            waitDuration: const Duration(milliseconds: 300),
            preferBelow: true,
            verticalOffset: 20,
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
                // Main entry container
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
                                    child: Text(
                                      habit!.icon,
                                      style: const TextStyle(fontSize: 12),
                                    ),
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
                                        child: Text(
                                          habit!.icon,
                                          style: const TextStyle(fontSize: 14),
                                        ),
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
                        onVerticalDragUpdate: _handleResizeUpdate,
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
                            child: _hoveringTop || (isBeingResized && _resizingTop)
                                ? const Icon(Icons.keyboard_arrow_up, size: 12, color: Colors.black54)
                                : null,
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
                        onVerticalDragUpdate: _handleResizeUpdate,
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
                            child: _hoveringBottom || (isBeingResized && !_resizingTop)
                                ? const Icon(Icons.keyboard_arrow_down, size: 12, color: Colors.black54)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
      );
    }
    
    return widgets;
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDragSelection() {
    int startMin = _dragStartMinutes!;
    int endMin = _dragEndMinutes!;
    
    if (endMin < startMin) {
      final temp = startMin;
      startMin = endMin;
      endMin = temp;
    }
    
    final startY = (startMin - widget.startHour * 60) / 60 * hourHeight;
    final height = ((endMin - startMin) / 60 * hourHeight).clamp(15.0, double.infinity);
    
    final startHour = startMin ~/ 60;
    final startMinute = startMin % 60;
    final endHour = endMin ~/ 60;
    final endMinute = endMin % 60;
    
    String formatTime(int h, int m) {
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:${m.toString().padLeft(2, '0')} $period';
    }
    
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
                '${formatTime(startHour, startMinute)} - ${formatTime(endHour, endMinute)}',
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

  Color _getCategoryColor(String category) {
    // Generate color based on category name hash for consistent colors
    final hash = category.hashCode;
    final colors = [
      const Color(0xFFFF453A), // Red
      const Color(0xFF30D158), // Green
      const Color(0xFFFF9F0A), // Orange
      const Color(0xFF00C7BE), // Teal
      const Color(0xFF5856D6), // Purple
      const Color(0xFF007AFF), // Blue
      const Color(0xFFAF52DE), // Magenta
      const Color(0xFFFFD60A), // Yellow
    ];
    return colors[hash.abs() % colors.length];
  }
}

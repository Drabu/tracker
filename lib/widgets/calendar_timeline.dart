import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

class CalendarTimeline extends StatefulWidget {
  final List<Event> entries;
  final Map<String, Habit> habitsMap;
  final Function(int startMinutes, int endMinutes) onDragCreate;
  final Function(Event entry, int index) onEntryTap;
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
  static const double resizeHandleHeight = 12.0;
  
  final ScrollController _scrollController = ScrollController();
  
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    if (!_scrollController.hasClients) return;
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final offset = (currentMinutes / 60) * hourHeight - 100;
    
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  int _getMinutesFromY(double y) {
    final totalMinutes = (y / hourHeight * 60).round();
    return ((totalMinutes / 5).round() * 5).clamp(0, 24 * 60 - 5);
  }

  void _handleDragStart(DragStartDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset;
    
    final minutes = _getMinutesFromY(y);
    
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

  void _handleResizeUpdate(DragUpdateDetails details) {
    if (!_isResizing || _resizingIndex == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final y = localPosition.dy + _scrollController.offset;
    final minutes = _getMinutesFromY(y);
    
    setState(() {
      if (_resizingTop) {
        _resizeStartMinutes = minutes.clamp(0, (_resizeEndMinutes ?? 24 * 60) - 10);
      } else {
        _resizeEndMinutes = minutes.clamp((_resizeStartMinutes ?? 0) + 10, 24 * 60);
      }
    });
  }

  void _handleResizeEnd() {
    if (_resizingIndex != null && _resizeStartMinutes != null && _resizeEndMinutes != null) {
      widget.onEntryResize?.call(_resizingIndex!, _resizeStartMinutes!, _resizeEndMinutes!);
    }
    setState(() {
      _isResizing = false;
      _resizingIndex = null;
      _resizeStartMinutes = null;
      _resizeEndMinutes = null;
    });
  }

  void _handleMoveStart(int index, DragStartDetails details) {
    final entry = widget.entries[index];
    HapticFeedback.lightImpact();
    setState(() {
      _isMoving = true;
      _movingIndex = index;
      _moveStartMinutes = entry.startMinutes;
      _moveEndMinutes = entry.endMinutes;
      _moveDragStartY = details.globalPosition.dy.round();
    });
  }

  void _handleMoveUpdate(DragUpdateDetails details) {
    if (!_isMoving || _movingIndex == null || _moveDragStartY == null) return;
    
    final entry = widget.entries[_movingIndex!];
    final deltaY = details.globalPosition.dy - _moveDragStartY!;
    final deltaMinutes = ((deltaY / hourHeight) * 60).round();
    final snappedDelta = (deltaMinutes / 5).round() * 5;
    
    final duration = entry.durationMinutes;
    int newStart = entry.startMinutes + snappedDelta;
    newStart = newStart.clamp(0, 24 * 60 - duration);
    final newEnd = newStart + duration;
    
    setState(() {
      _moveStartMinutes = newStart;
      _moveEndMinutes = newEnd;
    });
  }

  void _handleMoveEnd() {
    if (_movingIndex != null && _moveStartMinutes != null && _moveEndMinutes != null) {
      widget.onEntryMove?.call(_movingIndex!, _moveStartMinutes!, _moveEndMinutes!);
    }
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
    final totalHeight = 24 * hourHeight;
    
    return GestureDetector(
      onLongPressStart: (details) {
        _handleDragStart(DragStartDetails(globalPosition: details.globalPosition));
      },
      onLongPressMoveUpdate: (details) {
        _handleDragUpdate(DragUpdateDetails(globalPosition: details.globalPosition, delta: Offset.zero));
      },
      onLongPressEnd: (details) {
        _handleDragEnd(DragEndDetails());
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        child: SizedBox(
          height: totalHeight,
          child: Stack(
            children: [
              ..._buildHourLines(),
              ..._buildEntries(),
              _buildCurrentTimeIndicator(),
              if (_isDragging && _dragStartMinutes != null && _dragEndMinutes != null)
                _buildDragSelection(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHourLines() {
    final List<Widget> lines = [];
    
    for (int hour = 0; hour <= 24; hour++) {
      final y = hour * hourHeight;
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
                    hour == 24 ? '12 AM' :
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

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final y = (currentMinutes / 60) * hourHeight;
    
    return Positioned(
      left: timeGutterWidth - 4,
      top: y - 4,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEntries() {
    final List<Widget> widgets = [];
    
    for (int i = 0; i < widget.entries.length; i++) {
      final entry = widget.entries[i];
      final habit = widget.habitsMap[entry.habitId];
      final index = i;
      
      final isBeingResized = _isResizing && _resizingIndex == index;
      final isBeingMoved = _isMoving && _movingIndex == index;
      final isActive = isBeingResized || isBeingMoved;
      
      final displayStartMinutes = isBeingResized 
          ? _resizeStartMinutes! 
          : (isBeingMoved ? _moveStartMinutes! : entry.startMinutes);
      final displayEndMinutes = isBeingResized 
          ? _resizeEndMinutes! 
          : (isBeingMoved ? _moveEndMinutes! : entry.endMinutes);
      
      final startY = (displayStartMinutes / 60) * hourHeight;
      final height = ((displayEndMinutes - displayStartMinutes) / 60 * hourHeight).clamp(20.0, double.infinity);
      
      final color = _getCategoryColor(habit?.category ?? 'default');
      final isHovered = _hoveredEntryIndex == index;
      
      widgets.add(
        Positioned(
          left: timeGutterWidth + 4,
          top: startY,
          right: 8,
          height: height,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredEntryIndex = index),
            onExit: (_) => setState(() {
              _hoveredEntryIndex = null;
              _hoveringTop = false;
              _hoveringBottom = false;
            }),
            child: GestureDetector(
              onTap: () => widget.onEntryTap(entry, index),
              onVerticalDragStart: (details) => _handleMoveStart(index, details),
              onVerticalDragUpdate: (details) => _handleMoveUpdate(details),
              onVerticalDragEnd: (_) => _handleMoveEnd(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isActive ? 0.7 : 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive 
                            ? Colors.white 
                            : color.withValues(alpha: 0.3),
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ] : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => widget.onEntryTap(entry, index),
                        child: Padding(
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
                          onVerticalDragUpdate: (details) => _handleResizeUpdate(details),
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
                          onVerticalDragUpdate: (details) => _handleResizeUpdate(details),
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
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildDragSelection() {
    int startMin = _dragStartMinutes!;
    int endMin = _dragEndMinutes!;
    
    if (endMin < startMin) {
      final temp = startMin;
      startMin = endMin;
      endMin = temp;
    }
    
    final startY = (startMin / 60) * hourHeight;
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

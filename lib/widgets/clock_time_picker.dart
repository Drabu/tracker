import 'package:flutter/material.dart';
import 'dart:math' as math;

class ClockTimePicker extends StatefulWidget {
  final int hour;
  final int minute;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final String label;
  final Color? accentColor;

  const ClockTimePicker({
    super.key,
    required this.hour,
    required this.minute,
    required this.onTimeChanged,
    required this.label,
    this.accentColor,
  });

  @override
  State<ClockTimePicker> createState() => _ClockTimePickerState();
}

class _ClockTimePickerState extends State<ClockTimePicker> {
  late int _hour;
  late int _minute;
  late bool _isPM;
  bool _selectingHour = true;

  @override
  void initState() {
    super.initState();
    _hour = widget.hour;
    _minute = widget.minute;
    _isPM = widget.hour >= 12;
  }

  @override
  void didUpdateWidget(ClockTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hour != widget.hour || oldWidget.minute != widget.minute) {
      _hour = widget.hour;
      _minute = widget.minute;
      _isPM = widget.hour >= 12;
    }
  }

  int get _displayHour {
    if (_hour == 0) return 12;
    if (_hour > 12) return _hour - 12;
    return _hour;
  }

  void _updateTime(int hour24, int minute) {
    setState(() {
      _hour = hour24;
      _minute = minute;
      _isPM = hour24 >= 12;
    });
    widget.onTimeChanged(TimeOfDay(hour: hour24, minute: minute));
  }

  void _togglePeriod() {
    int newHour;
    if (_isPM) {
      newHour = _hour >= 12 ? _hour - 12 : _hour;
    } else {
      newHour = _hour < 12 ? _hour + 12 : _hour;
    }
    _updateTime(newHour, _minute);
  }

  void _onClockHourSelected(int hour12) {
    int hour24;
    if (_isPM) {
      hour24 = hour12 == 12 ? 12 : hour12 + 12;
    } else {
      hour24 = hour12 == 12 ? 0 : hour12;
    }
    _updateTime(hour24, _minute);
    setState(() => _selectingHour = false);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TimeDisplay(
              value: _displayHour.toString().padLeft(2, '0'),
              isSelected: _selectingHour,
              accentColor: accentColor,
              onTap: () => setState(() => _selectingHour = true),
            ),
            Text(
              ':',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            _TimeDisplay(
              value: _minute.toString().padLeft(2, '0'),
              isSelected: !_selectingHour,
              accentColor: accentColor,
              onTap: () => setState(() => _selectingHour = false),
            ),
            const SizedBox(width: 8),
            _PeriodToggle(
              isPM: _isPM,
              accentColor: accentColor,
              onToggle: _togglePeriod,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 130,
          height: 130,
          child: _ClockFace(
            hour12: _displayHour,
            minute: _minute,
            selectingHour: _selectingHour,
            accentColor: accentColor,
            onHourChanged: _onClockHourSelected,
            onMinuteChanged: (m) => _updateTime(_hour, m),
          ),
        ),
      ],
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  final bool isPM;
  final Color accentColor;
  final VoidCallback onToggle;

  const _PeriodToggle({
    required this.isPM,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: !isPM ? accentColor : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'PM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPM ? accentColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  final String value;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _TimeDisplay({
    required this.value,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isSelected ? accentColor : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

class _ClockFace extends StatelessWidget {
  final int hour12;
  final int minute;
  final bool selectingHour;
  final Color accentColor;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const _ClockFace({
    required this.hour12,
    required this.minute,
    required this.selectingHour,
    required this.accentColor,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final center = Offset(size / 2, size / 2);
        final radius = size / 2 - 8;

        return GestureDetector(
          onPanStart: (details) => _handleTouch(details.localPosition, center, radius),
          onPanUpdate: (details) => _handleTouch(details.localPosition, center, radius),
          onTapDown: (details) => _handleTouch(details.localPosition, center, radius),
          child: CustomPaint(
            size: Size(size, size),
            painter: _ClockPainter(
              hour12: hour12,
              minute: minute,
              selectingHour: selectingHour,
              accentColor: accentColor,
            ),
          ),
        );
      },
    );
  }

  void _handleTouch(Offset position, Offset center, double radius) {
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    if (selectingHour) {
      var h = (angle / (2 * math.pi) * 12).round() % 12;
      if (h == 0) h = 12;
      onHourChanged(h);
    } else {
      var m = ((angle / (2 * math.pi) * 60).round() % 60);
      m = (m ~/ 5) * 5;
      onMinuteChanged(m);
    }
  }
}

class _ClockPainter extends CustomPainter {
  final int hour12;
  final int minute;
  final bool selectingHour;
  final Color accentColor;

  _ClockPainter({
    required this.hour12,
    required this.minute,
    required this.selectingHour,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = Colors.grey.shade900
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    if (selectingHour) {
      _drawHourNumbers(canvas, center, radius);
      _drawHand(canvas, center, radius - 20, hour12);
    } else {
      _drawMinuteMarkers(canvas, center, radius);
      _drawMinuteHand(canvas, center, radius);
    }
  }

  void _drawHourNumbers(Canvas canvas, Offset center, double radius) {
    final numberRadius = radius - 18;

    for (int i = 1; i <= 12; i++) {
      final angle = (i / 12) * 2 * math.pi - math.pi / 2;
      final isSelected = hour12 == i;
      _drawNumber(canvas, center, numberRadius, angle, '$i', isSelected);
    }
  }

  void _drawNumber(Canvas canvas, Offset center, double radius, double angle, String text, bool isSelected) {
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);

    if (isSelected) {
      final highlightPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 14, highlightPaint);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.grey.shade400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  void _drawMinuteMarkers(Canvas canvas, Offset center, double radius) {
    final markerRadius = radius - 18;
    
    for (int i = 0; i < 12; i++) {
      final m = i * 5;
      final angle = (i / 12) * 2 * math.pi - math.pi / 2;
      final isSelected = minute == m;
      _drawNumber(canvas, center, markerRadius, angle, m.toString().padLeft(2, '0'), isSelected);
    }
  }

  void _drawMinuteHand(Canvas canvas, Offset center, double radius) {
    final angle = (minute / 60) * 2 * math.pi - math.pi / 2;
    final handLength = radius - 26;
    final end = Offset(
      center.dx + handLength * math.cos(angle),
      center.dy + handLength * math.sin(angle),
    );

    final handPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, end, handPaint);

    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  void _drawHand(Canvas canvas, Offset center, double handRadius, int value) {
    final angle = (value / 12) * 2 * math.pi - math.pi / 2;
    final end = Offset(
      center.dx + handRadius * math.cos(angle),
      center.dy + handRadius * math.sin(angle),
    );

    final handPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, end, handPaint);

    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) {
    return oldDelegate.hour12 != hour12 ||
        oldDelegate.minute != minute ||
        oldDelegate.selectingHour != selectingHour;
  }
}

class DualClockTimePicker extends StatelessWidget {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;

  const DualClockTimePicker({
    super.key,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ClockTimePicker(
            hour: startHour,
            minute: startMinute,
            onTimeChanged: onStartTimeChanged,
            label: 'START',
            accentColor: Colors.green,
          ),
        ),
        Container(
          width: 1,
          height: 180,
          color: Colors.grey.shade700,
        ),
        Expanded(
          child: ClockTimePicker(
            hour: endHour,
            minute: endMinute,
            onTimeChanged: onEndTimeChanged,
            label: 'END',
            accentColor: Colors.orange,
          ),
        ),
      ],
    );
  }
}

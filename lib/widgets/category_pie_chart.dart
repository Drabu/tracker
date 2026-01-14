import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../models/models.dart';

class CategoryPieChart extends StatefulWidget {
  final List<Event> entries;
  final double size;
  final double centerSpaceRadius;
  final bool showLegend;
  final bool showCompletionOverlay;
  final VoidCallback? onTap;

  const CategoryPieChart({
    super.key,
    required this.entries,
    this.size = 200,
    this.centerSpaceRadius = 50,
    this.showLegend = true,
    this.showCompletionOverlay = true,
    this.onTap,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;
  late AnimationController _animationController;
  late Animation<double> _animation;

  static const List<Color> _categoryColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime
    Color(0xFFEF4444), // Red
    Color(0xFF3B82F6), // Blue
    Color(0xFF14B8A6), // Teal
    Color(0xFFA855F7), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(CategoryPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Map<String, List<Event>> _groupByCategory() {
    final groups = <String, List<Event>>{};
    for (final entry in widget.entries) {
      final category = entry.habit.category.isEmpty
          ? 'Uncategorized'
          : entry.habit.category;
      groups.putIfAbsent(category, () => []);
      groups[category]!.add(entry);
    }
    return groups;
  }

  Color _getCategoryColor(int index) {
    return _categoryColors[index % _categoryColors.length];
  }

  double _getCompletionRate() {
    if (widget.entries.isEmpty) return 0.0;
    
    int completed = 0;
    for (var entry in widget.entries) {
      final status = entry.completionStatus;
      if (status == CompletionStatus.completed ||
          status == CompletionStatus.onTime ||
          status == CompletionStatus.delayed ||
          status == CompletionStatus.partial ||
          status == CompletionStatus.avoided) {
        completed++;
      }
    }
    return completed / widget.entries.length;
  }

  List<_SliceInfo> _calculateSliceInfo(Map<String, List<Event>> grouped, int totalMinutes, List<String> categories) {
    final List<_SliceInfo> slices = [];
    // fl_chart starts from -90 degrees (top) by default with startDegreeOffset
    // But the default is 0 which means right side (3 o'clock)
    // We need to match where the PieChart actually draws sections
    double currentAngle = -math.pi / 2; // Start from top (-90 degrees)
    
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final events = grouped[category]!;
      final categoryMinutes = events.fold<int>(0, (sum, e) => sum + e.durationMinutes);
      final percentage = (categoryMinutes / totalMinutes) * 100;
      final hours = categoryMinutes / 60;
      final sweepAngle = (categoryMinutes / totalMinutes) * 2 * math.pi;
      final middleAngle = currentAngle + sweepAngle / 2;
      
      slices.add(_SliceInfo(
        category: category,
        percentage: percentage,
        hours: hours,
        middleAngle: middleAngle,
        color: _getCategoryColor(i),
      ));
      
      currentAngle += sweepAngle;
    }
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = _groupByCategory();
    final totalMinutes = widget.entries.fold<int>(0, (sum, e) => sum + e.durationMinutes);
    final categories = grouped.keys.toList();
    final completionRate = _getCompletionRate();
    final sliceInfo = _calculateSliceInfo(grouped, totalMinutes, categories);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: Size(widget.size + 140, widget.size + 80),
                painter: _LabelArrowPainter(
                  slices: sliceInfo,
                  chartRadius: widget.size / 2,
                  centerOffset: Offset((widget.size + 140) / 2, (widget.size + 80) / 2),
                  animation: _animation.value,
                ),
                child: SizedBox(
                  width: widget.size + 140,
                  height: widget.size + 80,
                  child: Center(
                    child: SizedBox(
                      height: widget.size,
                      width: widget.size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedIndex = -1;
                                      return;
                                    }
                                    _touchedIndex = pieTouchResponse
                                        .touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: widget.centerSpaceRadius,
                              startDegreeOffset: -90, // Start from top to match arrow calculations
                              sections: categories.asMap().entries.map((entry) {
                                final index = entry.key;
                                final category = entry.value;
                                final events = grouped[category]!;
                                final categoryMinutes = events.fold<int>(
                                    0, (sum, e) => sum + e.durationMinutes);
                                final isTouched = index == _touchedIndex;
                                final baseRadius = widget.size * 0.22;
                                final radius = isTouched ? baseRadius + 6 : baseRadius;
                                final color = _getCategoryColor(index);

                                return PieChartSectionData(
                                  color: color,
                                  value: categoryMinutes.toDouble() * _animation.value,
                                  title: '',
                                  radius: radius * _animation.value,
                                  showTitle: false,
                                );
                              }).toList(),
                            ),
                          ),
                          if (widget.showCompletionOverlay)
                            _buildCompletionOverlay(completionRate),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${((totalMinutes / (24 * 60)) * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'of Day',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(totalMinutes / 60).toStringAsFixed(1)}h / 24h',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showLegend) ...[
                const SizedBox(height: 8),
                _buildLegend(grouped, totalMinutes),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompletionOverlay(double completionRate) {
    final outerRadius = widget.centerSpaceRadius + (widget.size * 0.22);
    final innerRadius = widget.centerSpaceRadius;
    
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _CompletionArcPainter(
        completionRate: completionRate * _animation.value,
        outerRadius: outerRadius,
        innerRadius: innerRadius,
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 40,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No activities',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Map<String, List<Event>> grouped, int totalMinutes) {
    final categories = grouped.keys.toList();
    
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final events = grouped[category]!;
        final categoryMinutes = events.fold<int>(0, (sum, e) => sum + e.durationMinutes);
        final hours = categoryMinutes / 60;
        final percentage = (categoryMinutes / totalMinutes) * 100;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getCategoryColor(index),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$category (${percentage.toStringAsFixed(0)}% · ${hours.toStringAsFixed(1)}h)',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _SliceInfo {
  final String category;
  final double percentage;
  final double hours;
  final double middleAngle;
  final Color color;

  _SliceInfo({
    required this.category,
    required this.percentage,
    required this.hours,
    required this.middleAngle,
    required this.color,
  });
}

class _LabelArrowPainter extends CustomPainter {
  final List<_SliceInfo> slices;
  final double chartRadius;
  final Offset centerOffset;
  final double animation;

  _LabelArrowPainter({
    required this.slices,
    required this.chartRadius,
    required this.centerOffset,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    // First pass: calculate all label positions
    final List<_LabelPosition> leftLabels = [];
    final List<_LabelPosition> rightLabels = [];
    
    for (final slice in slices) {
      final angle = slice.middleAngle;
      final isRightSide = angle > -math.pi / 2 && angle < math.pi / 2;
      
      // Point on the pie edge
      final pieEdgeRadius = chartRadius * 0.78;
      final pieX = centerOffset.dx + math.cos(angle) * pieEdgeRadius;
      final pieY = centerOffset.dy + math.sin(angle) * pieEdgeRadius;
      
      // Extended point for the elbow - keep original angle direction
      final elbowRadius = chartRadius + 12;
      final elbowX = centerOffset.dx + math.cos(angle) * elbowRadius;
      final elbowY = centerOffset.dy + math.sin(angle) * elbowRadius;
      
      final labelPos = _LabelPosition(
        slice: slice,
        pieX: pieX,
        pieY: pieY,
        elbowX: elbowX,
        elbowY: elbowY,
        labelY: elbowY,
        isRightSide: isRightSide,
      );
      
      if (isRightSide) {
        rightLabels.add(labelPos);
      } else {
        leftLabels.add(labelPos);
      }
    }
    
    // Sort labels by their original Y position (elbowY) to maintain slice order
    leftLabels.sort((a, b) => a.elbowY.compareTo(b.elbowY));
    rightLabels.sort((a, b) => a.elbowY.compareTo(b.elbowY));
    
    // Resolve overlaps - minimum spacing between labels
    const minSpacing = 26.0;
    _resolveOverlaps(leftLabels, minSpacing);
    _resolveOverlaps(rightLabels, minSpacing);
    
    // Draw all labels
    final allLabels = [...leftLabels, ...rightLabels];
    
    for (final labelPos in allLabels) {
      final slice = labelPos.slice;
      final lineLength = 30.0;
      
      // Calculate horizontal line end position
      final lineEndX = labelPos.isRightSide 
          ? centerOffset.dx + chartRadius + 50
          : centerOffset.dx - chartRadius - 50;
      
      // Draw the arrow line
      final linePaint = Paint()
        ..color = slice.color.withOpacity(0.8 * animation)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      
      // Path: pie edge -> elbow (original direction) -> bend to label Y -> horizontal to text
      final path = Path()
        ..moveTo(labelPos.pieX, labelPos.pieY)
        ..lineTo(labelPos.elbowX, labelPos.elbowY);
      
      // If label was moved, add connecting segments
      if ((labelPos.labelY - labelPos.elbowY).abs() > 2) {
        // Draw a smooth curve from elbow to the adjusted label position
        final midX = labelPos.isRightSide 
            ? labelPos.elbowX + 10 
            : labelPos.elbowX - 10;
        path.quadraticBezierTo(
          midX, labelPos.elbowY,
          midX, labelPos.labelY,
        );
        path.lineTo(lineEndX, labelPos.labelY);
      } else {
        // Direct horizontal line
        path.lineTo(lineEndX, labelPos.labelY);
      }
      
      canvas.drawPath(path, linePaint);
      
      // Draw small dot at the end
      final dotPaint = Paint()
        ..color = slice.color.withOpacity(animation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lineEndX, labelPos.labelY), 3, dotPaint);
      
      // Draw text labels
      final categoryText = '${slice.category} ${slice.percentage.toStringAsFixed(0)}%';
      final hoursText = '${slice.hours.toStringAsFixed(1)}h';
      
      // Category + percentage
      textPainter.text = TextSpan(
        text: categoryText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.9 * animation),
        ),
      );
      textPainter.layout();
      
      final textX = labelPos.isRightSide ? lineEndX + 8 : lineEndX - textPainter.width - 8;
      final textY = labelPos.labelY - textPainter.height / 2 - 6;
      textPainter.paint(canvas, Offset(textX, textY));
      
      // Hours
      textPainter.text = TextSpan(
        text: hoursText,
        style: TextStyle(
          fontSize: 10,
          color: Colors.white.withOpacity(0.5 * animation),
        ),
      );
      textPainter.layout();
      
      final hoursX = labelPos.isRightSide ? lineEndX + 8 : lineEndX - textPainter.width - 8;
      final hoursY = labelPos.labelY - textPainter.height / 2 + 6;
      textPainter.paint(canvas, Offset(hoursX, hoursY));
    }
  }
  
  void _resolveOverlaps(List<_LabelPosition> labels, double minSpacing) {
    if (labels.length < 2) return;
    
    // Push labels apart if they overlap
    for (int i = 1; i < labels.length; i++) {
      final prev = labels[i - 1];
      final current = labels[i];
      
      if (current.labelY - prev.labelY < minSpacing) {
        // Push current label down
        labels[i] = current.copyWith(labelY: prev.labelY + minSpacing);
      }
    }
    
    // If labels went too far down, push them back up proportionally
    final maxY = centerOffset.dy + chartRadius + 50;
    if (labels.isNotEmpty && labels.last.labelY > maxY) {
      final overflow = labels.last.labelY - maxY;
      final adjustment = overflow / labels.length;
      
      for (int i = 0; i < labels.length; i++) {
        labels[i] = labels[i].copyWith(
          labelY: labels[i].labelY - (adjustment * (labels.length - i)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LabelArrowPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.slices != slices;
  }
}

class _LabelPosition {
  final _SliceInfo slice;
  final double pieX;
  final double pieY;
  final double elbowX;
  final double elbowY;
  final double labelY;
  final bool isRightSide;

  _LabelPosition({
    required this.slice,
    required this.pieX,
    required this.pieY,
    required this.elbowX,
    required this.elbowY,
    required this.labelY,
    required this.isRightSide,
  });

  _LabelPosition copyWith({double? labelY}) {
    return _LabelPosition(
      slice: slice,
      pieX: pieX,
      pieY: pieY,
      elbowX: elbowX,
      elbowY: elbowY,
      labelY: labelY ?? this.labelY,
      isRightSide: isRightSide,
    );
  }
}

class _CompletionArcPainter extends CustomPainter {
  final double completionRate;
  final double outerRadius;
  final double innerRadius;

  _CompletionArcPainter({
    required this.completionRate,
    required this.outerRadius,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: outerRadius);
    
    final sweepAngle = 2 * math.pi * completionRate;
    final startAngle = -math.pi / 2;
    
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [
        const Color(0xFF30D158).withOpacity(0.4),
        const Color(0xFF34D399).withOpacity(0.5),
        const Color(0xFF10B981).withOpacity(0.45),
        const Color(0xFF30D158).withOpacity(0.4),
      ],
      stops: const [0.0, 0.33, 0.66, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );
    
    final completedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerRadius - innerRadius + 2
      ..shader = gradient.createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: (outerRadius + innerRadius) / 2),
      startAngle,
      sweepAngle,
      false,
      completedPaint,
    );
    
    if (completionRate > 0 && completionRate < 1) {
      final edgeAngle = startAngle + sweepAngle;
      final edgeX = center.dx + (outerRadius + innerRadius) / 2 * math.cos(edgeAngle);
      final edgeY = center.dy + (outerRadius + innerRadius) / 2 * math.sin(edgeAngle);
      
      final glowPaint = Paint()
        ..color = const Color(0xFF30D158)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawCircle(Offset(edgeX, edgeY), 4, glowPaint);
      
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(edgeX, edgeY), 3, dotPaint);
    }
    
    if (completionRate < 1) {
      final uncompletedSweep = 2 * math.pi * (1 - completionRate);
      final uncompletedStart = startAngle + sweepAngle;
      
      final uncompletedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerRadius - innerRadius + 2
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (outerRadius + innerRadius) / 2),
        uncompletedStart,
        uncompletedSweep,
        false,
        uncompletedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompletionArcPainter oldDelegate) {
    return oldDelegate.completionRate != completionRate;
  }
}

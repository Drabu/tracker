import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/glassmorphism_theme.dart';
import '../models/models.dart';

/// Apple glassmorphism time distribution donut chart
/// Shows how time is distributed across different categories
class GlassTimeDistribution extends StatelessWidget {
  final List<Event> entries;
  final Map<String, Habit> habitsMap;

  const GlassTimeDistribution({
    super.key,
    required this.entries,
    required this.habitsMap,
  });

  Map<String, int> _getCategoryMinutes() {
    final Map<String, int> categoryMinutes = {};
    
    for (var entry in entries) {
      final habit = habitsMap[entry.habitId];
      final category = habit?.category ?? 'Other';
      categoryMinutes[category] = (categoryMinutes[category] ?? 0) + entry.durationMinutes;
    }
    
    return categoryMinutes;
  }

  static const List<Color> _categoryColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFFA855F7), // Purple
    Color(0xFFFBBF24), // Amber
    Color(0xFF22D3EE), // Cyan
    Color(0xFF4ADE80), // Mint
    Color(0xFFF472B6), // Pink
  ];

  @override
  Widget build(BuildContext context) {
    final categoryMinutes = _getCategoryMinutes();
    final totalMinutes = categoryMinutes.values.fold(0, (a, b) => a + b);
    final totalHours = totalMinutes / 60;
    final percentage = (totalHours / 24 * 100).round();
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: GlassTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'TIME DISTRIBUTION',
                style: GlassTheme.headerTitle,
              ),
              const Spacer(),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 13,
                  color: GlassTheme.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Donut chart with center text
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: DonutChartPainter(
                    categoryMinutes: categoryMinutes,
                    colors: _categoryColors,
                  ),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${totalHours.toStringAsFixed(1)} fdy',
                      style: TextStyle(
                        fontSize: 12,
                        color: GlassTheme.textMuted,
                      ),
                    ),
                    Text(
                      '${totalHours.toStringAsFixed(1)}h / 24h',
                      style: TextStyle(
                        fontSize: 11,
                        color: GlassTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Legend
          ...categoryMinutes.entries.toList().asMap().entries.map((mapEntry) {
            final index = mapEntry.key;
            final entry = mapEntry.value;
            final color = _categoryColors[index % _categoryColors.length];
            final hours = entry.value / 60;
            final pct = totalMinutes > 0 ? (entry.value / totalMinutes * 100).round() : 0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${entry.key} $pct%',
                    style: TextStyle(
                      fontSize: 13,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${hours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      fontSize: 12,
                      color: GlassTheme.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<String, int> categoryMinutes;
  final List<Color> colors;
  
  DonutChartPainter({
    required this.categoryMinutes,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 28.0;
    final innerRadius = radius - strokeWidth;
    
    final total = categoryMinutes.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      // Draw empty ring
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, innerRadius + strokeWidth / 2, paint);
      return;
    }
    
    double startAngle = -math.pi / 2; // Start from top
    final entries = categoryMinutes.entries.toList();
    
    for (int i = 0; i < entries.length; i++) {
      final sweepAngle = (entries[i].value / total) * 2 * math.pi;
      final color = colors[i % colors.length];
      
      final paint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [color, color.withOpacity(0.7)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius + strokeWidth / 2),
        startAngle,
        sweepAngle - 0.02, // Small gap between segments
        false,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

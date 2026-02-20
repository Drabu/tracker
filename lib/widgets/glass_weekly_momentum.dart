import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../theme/glassmorphism_theme.dart';
import '../services/api_service.dart';

/// Apple glassmorphism weekly momentum line chart
/// Shows points over the last 7 days with a smooth gradient line
class GlassWeeklyMomentum extends StatefulWidget {
  final String userId;

  const GlassWeeklyMomentum({
    super.key,
    required this.userId,
  });

  @override
  State<GlassWeeklyMomentum> createState() => _GlassWeeklyMomentumState();
}

class _GlassWeeklyMomentumState extends State<GlassWeeklyMomentum> {
  List<int> _weeklyPoints = [0, 0, 0, 0, 0, 0, 0];
  int _totalPoints = 0;
  int _activeDays = 0;
  int _bestScore = 0;
  int _averagePoints = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    try {
      final stats = await ApiService.getWeeklyStats(widget.userId);
      if (mounted) {
        setState(() {
          _weeklyPoints = stats['dailyPoints'] ?? [0, 0, 0, 0, 0, 0, 0];
          _totalPoints = stats['totalPoints'] ?? 0;
          _activeDays = stats['activeDays'] ?? 0;
          _bestScore = stats['bestScore'] ?? 0;
          _averagePoints = _weeklyPoints.isNotEmpty 
              ? (_weeklyPoints.reduce((a, b) => a + b) / _weeklyPoints.length).round()
              : 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading weekly stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = ['Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Today'];
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: GlassTheme.accentMint.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: GlassTheme.accentMint,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'WEEKLY MOMENTUM',
                style: GlassTheme.headerTitle,
              ),
              const Spacer(),
              StatusBadge(
                text: '$_averagePoints avg',
                color: GlassTheme.accentCyan,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Let's go! 🚀",
            style: TextStyle(
              fontSize: 14,
              color: GlassTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Chart
          SizedBox(
            height: 120,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    children: [
                      // Y-axis labels
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('100', style: _axisStyle),
                          Text('50', style: _axisStyle),
                          Text('0', style: _axisStyle),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Chart area
                      Expanded(
                        child: CustomPaint(
                          size: const Size(double.infinity, 120),
                          painter: MomentumChartPainter(
                            points: _weeklyPoints,
                            maxValue: 100,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          
          // X-axis labels
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((day) {
                final isToday = day == 'Today';
                return Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    color: isToday ? GlassTheme.textPrimary : GlassTheme.textMuted,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('$_totalPoints', 'Total', GlassTheme.accentCyan),
                _buildDivider(),
                _buildStat('$_activeDays/7', 'Active', GlassTheme.accentCyan),
                _buildDivider(),
                _buildStat('$_bestScore', 'Best', GlassTheme.accentMint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _axisStyle => TextStyle(
    fontSize: 10,
    color: GlassTheme.textMuted,
  );

  Widget _buildStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: GlassTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withOpacity(0.1),
    );
  }
}

class MomentumChartPainter extends CustomPainter {
  final List<int> points;
  final int maxValue;

  MomentumChartPainter({
    required this.points,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final width = size.width;
    final height = size.height;
    final stepX = width / (points.length - 1);
    
    // Calculate point positions
    final pointPositions = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i] / maxValue).clamp(0.0, 1.0);
      final y = height - (normalizedY * height);
      pointPositions.add(Offset(x, y));
    }
    
    // Draw grid line
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, height / 2),
      Offset(width, height / 2),
      gridPaint,
    );
    
    // Create gradient for area fill
    final areaPath = Path()
      ..moveTo(0, height);
    
    for (final pos in pointPositions) {
      areaPath.lineTo(pos.dx, pos.dy);
    }
    areaPath.lineTo(width, height);
    areaPath.close();
    
    final areaGradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(0, height),
      [
        GlassTheme.accentMint.withOpacity(0.3),
        GlassTheme.accentMint.withOpacity(0.0),
      ],
    );
    
    final areaPaint = Paint()
      ..shader = areaGradient
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(areaPath, areaPaint);
    
    // Draw line
    final linePath = Path();
    for (int i = 0; i < pointPositions.length; i++) {
      if (i == 0) {
        linePath.moveTo(pointPositions[i].dx, pointPositions[i].dy);
      } else {
        linePath.lineTo(pointPositions[i].dx, pointPositions[i].dy);
      }
    }
    
    final lineGradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(width, 0),
      [GlassTheme.accentCyan, GlassTheme.accentMint],
    );
    
    final linePaint = Paint()
      ..shader = lineGradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(linePath, linePaint);
    
    // Draw "Today" point (last point)
    if (pointPositions.isNotEmpty) {
      final lastPoint = pointPositions.last;
      
      // Outer glow
      final glowPaint = Paint()
        ..color = GlassTheme.accentMint.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastPoint, 12, glowPaint);
      
      // Outer ring
      final outerPaint = Paint()
        ..color = const Color(0xFF1A2235)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastPoint, 8, outerPaint);
      
      // Inner ring
      final ringPaint = Paint()
        ..color = GlassTheme.accentMint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(lastPoint, 6, ringPaint);
      
      // Center dot
      final dotPaint = Paint()
        ..color = GlassTheme.accentMint
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastPoint, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

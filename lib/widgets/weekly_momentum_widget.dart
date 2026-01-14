import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class WeeklyMomentumWidget extends StatefulWidget {
  const WeeklyMomentumWidget({super.key});

  @override
  State<WeeklyMomentumWidget> createState() => _WeeklyMomentumWidgetState();
}

class _WeeklyMomentumWidgetState extends State<WeeklyMomentumWidget>
    with SingleTickerProviderStateMixin {
  List<int> _dailyPoints = List.filled(7, 0);
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  static const int maxPoints = 100;

  // Theme colors matching the app
  static const Color _cardBackground = Color(0xFF1A1A2E);
  static const Color _primaryGreen = Color(0xFF30D158);
  static const Color _accentYellow = Color(0xFFF59E0B);
  static const Color _textPrimary = Colors.white;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _loadWeeklyData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyData() async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return;

    try {
      final List<int> points = [];
      final today = DateTime.now();

      // Fetch data for last 7 days (including today)
      for (int i = 6; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        try {
          final timeline = await ApiService.getTimelineByDate(userId, dateStr);
          if (timeline != null && timeline.entries.isNotEmpty) {
            int dayPoints = 0;
            for (var entry in timeline.entries) {
              if (entry.completionStatus == CompletionStatus.completed ||
                  entry.completionStatus == CompletionStatus.onTime ||
                  entry.completionStatus == CompletionStatus.delayed ||
                  entry.completionStatus == CompletionStatus.partial) {
                dayPoints += entry.points;
              }
            }
            points.add(math.min(dayPoints, maxPoints));
          } else {
            points.add(0);
          }
        } catch (e) {
          points.add(0);
        }
      }

      if (mounted) {
        setState(() {
          _dailyPoints = points;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getInsightMessage() {
    if (_dailyPoints.every((p) => p == 0)) {
      return "Start your journey today! 🌟";
    }

    final nonZeroDays = _dailyPoints.where((p) => p > 0).length;
    final average = _dailyPoints.reduce((a, b) => a + b) / _dailyPoints.length;
    final lastThreeDays = _dailyPoints.sublist(4);
    final firstThreeDays = _dailyPoints.sublist(0, 3);
    final lastThreeAvg = lastThreeDays.reduce((a, b) => a + b) / 3;
    final firstThreeAvg = firstThreeDays.reduce((a, b) => a + b) / 3;

    if (lastThreeAvg > firstThreeAvg + 10) {
      return "You're improving! 📈";
    }

    if (nonZeroDays >= 6 && average > 50) {
      return "Great consistency! 👏";
    }

    if (nonZeroDays >= 5) {
      return "Keep it going! 🔥";
    }

    final todayPoints = _dailyPoints.last;
    if (todayPoints >= 80) {
      return "Amazing day! ⭐";
    }

    if (todayPoints > 0) {
      return "Good start! 💪";
    }

    return "Let's go! 🚀";
  }

  List<String> _getDayLabels() {
    final labels = <String>[];
    final today = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      if (i == 0) {
        labels.add('Today');
      } else {
        labels.add(weekdays[date.weekday - 1]);
      }
    }
    return labels;
  }

  int _calculateWeeklyAverage() {
    final nonZeroPoints = _dailyPoints.where((p) => p > 0).toList();
    if (nonZeroPoints.isEmpty) return 0;
    return (nonZeroPoints.reduce((a, b) => a + b) / nonZeroPoints.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final weeklyAvg = _calculateWeeklyAverage();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: _primaryGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'WEEKLY MOMENTUM',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Average badge
              if (!_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$weeklyAvg avg',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle with insight
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Opacity(
                opacity: _animation.value,
                child: Text(
                  _isLoading ? 'Loading...' : _getInsightMessage(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _textPrimary.withValues(alpha: 0.5),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Chart
          _isLoading
              ? const SizedBox(
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _primaryGreen,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return SizedBox(
                      height: 140,
                      child: _buildChart(),
                    );
                  },
                ),

          const SizedBox(height: 16),

          // Stats row
          if (!_isLoading) _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final dayLabels = _getDayLabels();
    final animatedPoints = _dailyPoints
        .map((p) => (p * _animation.value).toDouble())
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= dayLabels.length) {
                  return const SizedBox.shrink();
                }
                final isToday = index == 6;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dayLabels[index],
                    style: TextStyle(
                      color: isToday
                          ? _primaryGreen
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == 50 || value == 100) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 9,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 100,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF2D2D3A),
            tooltipBorder: BorderSide(
              color: _primaryGreen.withValues(alpha: 0.3),
              width: 1,
            ),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()} pts',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              7,
              (index) => FlSpot(index.toDouble(), animatedPoints[index]),
            ),
            isCurved: true,
            curveSmoothness: 0.3,
            color: _primaryGreen,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isToday = index == 6;
                final hasPoints = _dailyPoints[index] > 0;

                if (isToday) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: _primaryGreen,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                }

                if (hasPoints) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: _primaryGreen,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                }

                return FlDotCirclePainter(
                  radius: 2,
                  color: Colors.white.withValues(alpha: 0.2),
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _primaryGreen.withValues(alpha: 0.2),
                  _primaryGreen.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalPoints = _dailyPoints.reduce((a, b) => a + b);
    final activeDays = _dailyPoints.where((p) => p > 0).length;
    final bestDay = _dailyPoints.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            value: '$totalPoints',
            label: 'Total',
            color: _accentYellow,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _buildStatItem(
            value: '$activeDays/7',
            label: 'Active',
            color: _primaryGreen,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _buildStatItem(
            value: '$bestDay',
            label: 'Best',
            color: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

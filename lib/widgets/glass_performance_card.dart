import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';

/// Apple glassmorphism performance summary card
/// Shows completed/remaining habits, completion rate, and progress bar
class GlassPerformanceCard extends StatelessWidget {
  final String userName;
  final int completedCount;
  final int remainingCount;
  final double completionRate;
  final int habitsCompleted;
  final int totalHabits;

  const GlassPerformanceCard({
    super.key,
    required this.userName,
    required this.completedCount,
    required this.remainingCount,
    required this.completionRate,
    required this.habitsCompleted,
    required this.totalHabits,
  });

  String _getPerformanceStatus() {
    if (completionRate >= 0.8) return 'EXCELLENT';
    if (completionRate >= 0.6) return 'GOOD';
    if (completionRate >= 0.4) return 'FAIR';
    return 'NEEDS WORK';
  }

  Color _getStatusColor() {
    if (completionRate >= 0.8) return GlassTheme.accentMint;
    if (completionRate >= 0.6) return GlassTheme.accentCyan;
    if (completionRate >= 0.4) return GlassTheme.accentAmber;
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  "${userName.toUpperCase()}'S PERFORMANCE",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: GlassTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                text: _getPerformanceStatus(),
                color: _getStatusColor(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Stats boxes row
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  icon: Icons.check_box_outlined,
                  value: completedCount.toString(),
                  label: 'COMPLETED',
                  color: GlassTheme.accentMint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  icon: Icons.thumb_up_outlined,
                  value: remainingCount.toString(),
                  label: 'REMAINING',
                  color: GlassTheme.accentAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Completion rate
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(completionRate * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: GlassTheme.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '〜',
                  style: TextStyle(
                    fontSize: 18,
                    color: GlassTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'COMPLETION RATE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              color: GlassTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          GlassProgressBar(
            progress: completionRate,
            startColor: GlassTheme.accentMint,
            endColor: GlassTheme.accentCyan,
            height: 8,
          ),
          const SizedBox(height: 8),
          
          // Habits count
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$habitsCompleted of $totalHabits habits',
              style: const TextStyle(
                fontSize: 12,
                color: GlassTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: GlassTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

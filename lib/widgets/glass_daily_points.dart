import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';

/// Apple glassmorphism daily points card
/// Shows earned points out of total with a progress bar
class GlassDailyPointsCard extends StatelessWidget {
  final int earnedPoints;
  final int totalPoints;

  const GlassDailyPointsCard({
    super.key,
    required this.earnedPoints,
    required this.totalPoints,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalPoints > 0 ? earnedPoints / totalPoints : 0.0;
    final percentage = (progress * 100).round();
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      glowColor: GlassTheme.accentMint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: GlassTheme.accentMint,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.accentMint.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'DAILY POINTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Points count and percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$earnedPoints of $totalPoints points',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: GlassTheme.textPrimary,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GlassTheme.accentMint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          GlassProgressBar(
            progress: progress,
            startColor: GlassTheme.accentMint,
            endColor: GlassTheme.accentCyan,
            height: 8,
          ),
        ],
      ),
    );
  }
}

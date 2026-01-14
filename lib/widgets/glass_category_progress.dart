import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';
import '../models/models.dart';

/// Apple glassmorphism category progress bars
/// Shows completion progress for each habit category
class GlassCategoryProgress extends StatelessWidget {
  final List<Event> entries;
  final Map<String, Habit> habitsMap;

  const GlassCategoryProgress({
    super.key,
    required this.entries,
    required this.habitsMap,
  });

  static const List<Color> _categoryColors = [
    Color(0xFF22D3EE), // Cyan
    Color(0xFFFBBF24), // Amber
    Color(0xFF4ADE80), // Mint
    Color(0xFFA855F7), // Purple
    Color(0xFF3B82F6), // Blue
    Color(0xFFF472B6), // Pink
  ];

  Map<String, Map<String, int>> _getCategoryStats() {
    final Map<String, Map<String, int>> categoryStats = {};
    
    for (var entry in entries) {
      final habit = habitsMap[entry.habitId];
      final category = habit?.category ?? 'Other';
      
      if (!categoryStats.containsKey(category)) {
        categoryStats[category] = {'completed': 0, 'total': 0};
      }
      
      categoryStats[category]!['total'] = categoryStats[category]!['total']! + 1;
      
      final isCompleted = entry.completionStatus == CompletionStatus.completed ||
                          entry.completionStatus == CompletionStatus.onTime ||
                          entry.completionStatus == CompletionStatus.delayed ||
                          entry.completionStatus == CompletionStatus.partial;
      
      if (isCompleted) {
        categoryStats[category]!['completed'] = categoryStats[category]!['completed']! + 1;
      }
    }
    
    return categoryStats;
  }

  @override
  Widget build(BuildContext context) {
    final categoryStats = _getCategoryStats();
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY PROGRESS',
            style: GlassTheme.headerTitle,
          ),
          const SizedBox(height: 20),
          ...categoryStats.entries.toList().asMap().entries.map((mapEntry) {
            final index = mapEntry.key;
            final entry = mapEntry.value;
            final color = _categoryColors[index % _categoryColors.length];
            final completed = entry.value['completed']!;
            final total = entry.value['total']!;
            final progress = total > 0 ? completed / total : 0.0;
            final percentage = (progress * 100).round();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '$completed/$total tasks ($percentage%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: GlassTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildProgressBar(progress, color),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, Color color) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

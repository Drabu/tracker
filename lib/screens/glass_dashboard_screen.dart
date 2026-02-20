import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_performance_card.dart';
import '../widgets/glass_time_distribution.dart';
import '../widgets/glass_weekly_momentum.dart';
import '../widgets/glass_category_progress.dart';
import '../widgets/glass_contests_card.dart';
import '../widgets/glass_daily_points.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart';

class GlassDashboardScreen extends StatefulWidget {
  const GlassDashboardScreen({super.key});

  @override
  State<GlassDashboardScreen> createState() => _GlassDashboardScreenState();
}

class _GlassDashboardScreenState extends State<GlassDashboardScreen> {
  String get _currentUserId => AuthService.currentUser?.id ?? '';
  
  List<Event> _timelineEntries = [];
  Map<String, Habit> _habitsMap = {};
  Timeline? _currentTimeline;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;
  
  // Stats
  int _completedCount = 0;
  int _remainingCount = 0;
  int _totalPoints = 0;
  int _earnedPoints = 0;
  double _completionRate = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Auto-refresh every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadDashboardData();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadDashboardData() async {
    try {
      // Load habits first
      final habits = await ApiService.getHabits();
      _habitsMap = {for (var h in habits) h.id: h};
      
      // Load timeline for today
      final dateStr = _formatDateForApi(_selectedDate);
      final timeline = await ApiService.getTimelineByDate(_currentUserId, dateStr);
      
      if (mounted) {
        setState(() {
          _currentTimeline = timeline;
          _timelineEntries = timeline?.entries ?? [];
          _calculateStats();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _calculateStats() {
    _completedCount = 0;
    _remainingCount = 0;
    _totalPoints = 0;
    _earnedPoints = 0;
    
    for (var entry in _timelineEntries) {
      final isCompleted = entry.completionStatus == CompletionStatus.completed ||
                          entry.completionStatus == CompletionStatus.onTime ||
                          entry.completionStatus == CompletionStatus.delayed ||
                          entry.completionStatus == CompletionStatus.partial;
      
      if (isCompleted) {
        _completedCount++;
        _earnedPoints += entry.points;
      } else if (entry.completionStatus != CompletionStatus.missed &&
                 entry.completionStatus != CompletionStatus.avoided) {
        _remainingCount++;
      }
      _totalPoints += entry.points;
    }
    
    final total = _completedCount + _remainingCount;
    _completionRate = total > 0 ? _completedCount / total : 0.0;
  }
  
  String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  String _formatFullDate() {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = weekdays[_selectedDate.weekday - 1];
    final day = _selectedDate.day;
    final month = months[_selectedDate.month - 1];
    
    String suffix = 'th';
    if (day >= 11 && day <= 13) {
      suffix = 'th';
    } else {
      switch (day % 10) {
        case 1: suffix = 'st'; break;
        case 2: suffix = 'nd'; break;
        case 3: suffix = 'rd'; break;
      }
    }
    
    return '$weekday $day$suffix of $month';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1200;
    final isMedium = screenWidth > 800;
    
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          minimum: const EdgeInsets.only(top: 32),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: GlassTheme.accentCyan,
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),
                    // Main content
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: isWide
                          ? _buildWideLayout()
                          : isMedium
                              ? _buildMediumLayout()
                              : _buildNarrowLayout(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Text(
            "TODAY'S FOCUS",
            style: GlassTheme.headerTitle,
          ),
          const Spacer(),
          Text(
            _formatFullDate(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: GlassTheme.accentCyan,
            ),
          ),
          const Spacer(),
          Text(
            'INSIGHTS',
            style: GlassTheme.headerTitle,
          ),
          const Spacer(),
          Text(
            'ACTIVE CONTESTS',
            style: GlassTheme.headerTitle,
          ),
        ],
      ),
    );
  }
  
  Widget _buildWideLayout() {
    return SliverToBoxAdapter(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column - Today's Focus
          Expanded(
            flex: 3,
            child: Column(
              children: [
                GlassPerformanceCard(
                  userName: AuthService.currentUser?.name ?? 'User',
                  completedCount: _completedCount,
                  remainingCount: _remainingCount,
                  completionRate: _completionRate,
                  habitsCompleted: _completedCount,
                  totalHabits: _completedCount + _remainingCount,
                ),
                const SizedBox(height: 16),
                GlassTimeDistribution(
                  entries: _timelineEntries,
                  habitsMap: _habitsMap,
                ),
                const SizedBox(height: 16),
                GlassDailyPointsCard(
                  earnedPoints: _earnedPoints,
                  totalPoints: _totalPoints,
                ),
                const SizedBox(height: 16),
                _buildFocusModeCard(),
                const SizedBox(height: 16),
                _buildScheduleCard(),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Center column - Insights
          Expanded(
            flex: 3,
            child: Column(
              children: [
                GlassWeeklyMomentum(userId: _currentUserId),
                const SizedBox(height: 16),
                _buildActivityTimerCard(),
                const SizedBox(height: 16),
                GlassCategoryProgress(
                  entries: _timelineEntries,
                  habitsMap: _habitsMap,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right column - Contests & Points
          Expanded(
            flex: 2,
            child: Column(
              children: [
                const GlassContestsCard(),
                const SizedBox(height: 16),
                _buildQuickActions(),
                const SizedBox(height: 16),
                _buildCompoundHabitsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMediumLayout() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    GlassPerformanceCard(
                      userName: AuthService.currentUser?.name ?? 'User',
                      completedCount: _completedCount,
                      remainingCount: _remainingCount,
                      completionRate: _completionRate,
                      habitsCompleted: _completedCount,
                      totalHabits: _completedCount + _remainingCount,
                    ),
                    const SizedBox(height: 16),
                    GlassTimeDistribution(
                      entries: _timelineEntries,
                      habitsMap: _habitsMap,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    GlassWeeklyMomentum(userId: _currentUserId),
                    const SizedBox(height: 16),
                    GlassCategoryProgress(
                      entries: _timelineEntries,
                      habitsMap: _habitsMap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GlassDailyPointsCard(
                  earnedPoints: _earnedPoints,
                  totalPoints: _totalPoints,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildFocusModeCard()),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildNarrowLayout() {
    return SliverList(
      delegate: SliverChildListDelegate([
        GlassPerformanceCard(
          userName: AuthService.currentUser?.name ?? 'User',
          completedCount: _completedCount,
          remainingCount: _remainingCount,
          completionRate: _completionRate,
          habitsCompleted: _completedCount,
          totalHabits: _completedCount + _remainingCount,
        ),
        const SizedBox(height: 16),
        GlassWeeklyMomentum(userId: _currentUserId),
        const SizedBox(height: 16),
        GlassTimeDistribution(
          entries: _timelineEntries,
          habitsMap: _habitsMap,
        ),
        const SizedBox(height: 16),
        _buildFocusModeCard(),
        const SizedBox(height: 16),
        GlassDailyPointsCard(
          earnedPoints: _earnedPoints,
          totalPoints: _totalPoints,
        ),
        const SizedBox(height: 16),
        GlassCategoryProgress(
          entries: _timelineEntries,
          habitsMap: _habitsMap,
        ),
      ]),
    );
  }
  
  Widget _buildFocusModeCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GlassTheme.accentCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: GlassTheme.accentCyan,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus Mode',
                  style: GlassTheme.cardTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  'View current habit in full screen focus',
                  style: GlassTheme.bodyText,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: GlassTheme.textMuted,
          ),
        ],
      ),
    );
  }
  
  Widget _buildScheduleCard() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: GlassTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${weekdays[_selectedDate.weekday - 1]}, ${months[_selectedDate.month - 1]} ${_selectedDate.day}',
                style: GlassTheme.cardTitle,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh, color: GlassTheme.textMuted, size: 18),
                onPressed: _loadDashboardData,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show first few timeline entries
          ..._timelineEntries.take(3).map((entry) => _buildScheduleItem(entry)),
        ],
      ),
    );
  }
  
  Widget _buildScheduleItem(Event entry) {
    final habit = _habitsMap[entry.habitId];
    final isCompleted = entry.completionStatus == CompletionStatus.completed ||
                        entry.completionStatus == CompletionStatus.onTime;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted ? GlassTheme.accentMint : GlassTheme.accentAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            habit?.title ?? 'Unknown',
            style: TextStyle(
              fontSize: 14,
              color: GlassTheme.textPrimary,
            ),
          ),
          if (isCompleted) ...[
            const SizedBox(width: 8),
            StatusBadge(
              text: 'NOW',
              color: GlassTheme.accentAmber,
            ),
          ],
          const Spacer(),
          Text(
            '${entry.points} pts',
            style: TextStyle(
              fontSize: 12,
              color: GlassTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityTimerCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      glowColor: GlassTheme.accentCyan,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GlassTheme.accentCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.access_time,
              color: GlassTheme.accentCyan,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '01:39:05',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusBadge(
                      text: 'ACTIVE',
                      color: GlassTheme.accentMint,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: GlassTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No scheduled activity',
                  style: GlassTheme.cardTitle,
                ),
                Text(
                  'Stay consistent, stay strong',
                  style: GlassTheme.bodyText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionButton(Icons.check, true),
        const SizedBox(width: 8),
        _buildActionButton(Icons.check, false),
        const SizedBox(width: 8),
        _buildActionButton(Icons.emoji_events, false),
        const SizedBox(width: 8),
        _buildActionButton(Icons.cloud, false),
        const SizedBox(width: 8),
        _buildActionButton(Icons.delete_outline, false),
        const SizedBox(width: 8),
        _buildActionButton(Icons.menu, false),
      ],
    );
  }
  
  Widget _buildActionButton(IconData icon, bool isActive) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      opacity: isActive ? 0.15 : 0.08,
      glowColor: isActive ? GlassTheme.accentCyan : null,
      child: Icon(
        icon,
        size: 18,
        color: isActive ? GlassTheme.accentCyan : GlassTheme.textMuted,
      ),
    );
  }
  
  Widget _buildCompoundHabitsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: GlassTheme.accentAmber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'COMPOUND HABITS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Long-term growth habits that compound',
            style: GlassTheme.bodyText,
          ),
          const SizedBox(height: 8),
          Text(
            '0 of 1 completed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: GlassTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Today: None completed yet',
            style: TextStyle(
              fontSize: 12,
              color: GlassTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

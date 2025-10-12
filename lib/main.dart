import 'package:flutter/material.dart';
import 'dart:math' as math;

enum HabitState {
  none,
  onTime,
  delayed,
  partial,
  completed,
  missed,
  avoided
}

void main() {
  runApp(const DailyTrackerApp());
}

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Tracker',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        cardColor: const Color(0xFF161B22),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: false,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          secondary: Color(0xFF39D353),
          surface: Color(0xFF161B22),
        ),
      ),
      home: const DailyTrackerHome(),
    );
  }
}

enum ViewType { day, week, month, year }

class DailyTrackerHome extends StatefulWidget {
  const DailyTrackerHome({super.key});

  @override
  State<DailyTrackerHome> createState() => _DailyTrackerHomeState();
}

class _DailyTrackerHomeState extends State<DailyTrackerHome> with TickerProviderStateMixin {
  ViewType _currentView = ViewType.day;
  final DateTime _selectedDate = DateTime.now();
  DateTime _currentWeekStart = DateTime.now();
  final Map<String, Map<String, Map<int, HabitState>>> _trackingData = {}; // habit -> weekKey -> dayIndex -> state
  final Map<String, Map<String, Map<int, TimeOfDay?>>> _timeData = {}; // habit -> weekKey -> dayIndex -> time
  
  late AnimationController _progressAnimationController;
  late AnimationController _ringAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _ringAnimation;

  final List<String> _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  final Map<String, List<String>> _categories = {
    'Daily Habits': [
      'Cold Shower',
      'Quran',
      'Breakfast',
      'Lunch',
      'Mid Day Shower',
      'Gym',
      'Walk',
      'Typing',
      'Water',
      'Book',
    ],
    'Akhira (Salah)': [
      'Fajr',
      'Duhr',
      'Asr',
      'Maghrib',
      'Isha',
    ],
    'Breakfast Items': [
      'Eggs',
      'Meal',
      'Coffee',
    ],
    'Guitar Sessions': [
      'Bar Chord',
      'Fingerstyle',
      'Random',
    ],
    'Sleep Metrics': [
      'Bed Time (B.T.)',
      'Asleep Time (A.S.T.)',
      'Wake Time (W.T.)',
      'Midday Sleep',
    ],
  };

  final Set<String> _prayerHabits = {
    'Fajr', 'Duhr', 'Asr', 'Maghrib', 'Isha'
  };

  final Set<String> _timeBasedHabits = {
    'Fajr', 'Duhr', 'Asr', 'Maghrib', 'Isha', 'Gym', 'Bed Time (B.T.)'
  };

  final Set<String> _sleepTrackingHabits = {
    'Bed Time (B.T.)', 'Asleep Time (A.S.T.)', 'Wake Time (W.T.)', 'Midday Sleep'
  };

  final Map<String, Map<HabitState, int>> _habitStatePoints = {
    'Fajr': {HabitState.onTime: 30, HabitState.delayed: 20, HabitState.missed: 0},
    'Duhr': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Asr': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Maghrib': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Isha': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Gym': {HabitState.completed: 25, HabitState.partial: 15, HabitState.missed: 0},
    'Cold Shower': {HabitState.completed: 20, HabitState.missed: 0},
    'Quran': {HabitState.completed: 15, HabitState.partial: 8, HabitState.missed: 0},
    'Book': {HabitState.completed: 15, HabitState.partial: 8, HabitState.missed: 0},
    'Walk': {HabitState.completed: 10, HabitState.partial: 5, HabitState.missed: 0},
    'Typing': {HabitState.completed: 10, HabitState.partial: 5, HabitState.missed: 0},
    'Guitar': {HabitState.completed: 10, HabitState.partial: 5, HabitState.missed: 0},
    'Breakfast': {HabitState.completed: 5, HabitState.missed: 0},
    'Lunch': {HabitState.completed: 5, HabitState.missed: 0},
    'Mid Day Shower': {HabitState.completed: 10, HabitState.missed: 0},
    'Water': {HabitState.completed: 5, HabitState.partial: 3, HabitState.missed: 0},
    'Eggs': {HabitState.completed: 3, HabitState.missed: 0},
    'Meal': {HabitState.completed: 3, HabitState.missed: 0},
    'Coffee': {HabitState.completed: 2, HabitState.missed: 0},
    'Bar Chord': {HabitState.completed: 8, HabitState.partial: 4, HabitState.missed: 0},
    'Fingerstyle': {HabitState.completed: 8, HabitState.partial: 4, HabitState.missed: 0},
    'Random': {HabitState.completed: 5, HabitState.partial: 3, HabitState.missed: 0},
    'Bed Time (B.T.)': {HabitState.onTime: 5, HabitState.delayed: 2, HabitState.missed: 0},
    'Asleep Time (A.S.T.)': {HabitState.completed: 5, HabitState.missed: 0},
    'Wake Time (W.T.)': {HabitState.onTime: 5, HabitState.delayed: 2, HabitState.missed: 0},
    'Midday Sleep': {HabitState.avoided: 5, HabitState.completed: 0, HabitState.missed: 0},
  };

  void _showHabitStateDialog(String habit, int dayIndex) {
    List<HabitState> availableStates = _getAvailableStates(habit);
    bool isSleepTracking = _sleepTrackingHabits.contains(habit);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$habit - ${_weekDays[dayIndex]}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableStates.map((state) {
              int points = _habitStatePoints[habit]?[state] ?? 0;
              return ListTile(
                title: Text(_getStateDisplayName(state)),
                subtitle: Text('$points points'),
                onTap: () async {
                  if (isSleepTracking && state != HabitState.none && state != HabitState.missed) {
                    // Show time picker for sleep tracking items
                    if (!mounted) return;
                    TimeOfDay? selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    
                    if (selectedTime != null && mounted) {
                      setState(() {
                        _trackingData[habit] ??= {};
                        _trackingData[habit]![_currentWeekKey] ??= {};
                        _trackingData[habit]![_currentWeekKey]![dayIndex] = state;
                        _timeData[habit] ??= {};
                        _timeData[habit]![_currentWeekKey] ??= {};
                        _timeData[habit]![_currentWeekKey]![dayIndex] = selectedTime;
                      });
                      _animateProgressUpdate();
                    }
                  } else {
                    setState(() {
                      _trackingData[habit] ??= {};
                      _trackingData[habit]![_currentWeekKey] ??= {};
                      _trackingData[habit]![_currentWeekKey]![dayIndex] = state;
                      if (state == HabitState.none || state == HabitState.missed) {
                        _timeData[habit] ??= {};
                        _timeData[habit]![_currentWeekKey] ??= {};
                        _timeData[habit]![_currentWeekKey]![dayIndex] = null;
                      }
                    });
                    _animateProgressUpdate();
                  }
                  if (mounted) Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  List<HabitState> _getAvailableStates(String habit) {
    if (habit == 'Midday Sleep') {
      return [HabitState.none, HabitState.avoided, HabitState.completed, HabitState.missed];
    } else if (_prayerHabits.contains(habit)) {
      return [HabitState.none, HabitState.onTime, HabitState.delayed, HabitState.missed];
    } else if (_timeBasedHabits.contains(habit)) {
      return [HabitState.none, HabitState.onTime, HabitState.delayed, HabitState.missed];
    } else if (['Quran', 'Book', 'Gym', 'Walk', 'Typing', 'Water'].contains(habit)) {
      return [HabitState.none, HabitState.completed, HabitState.partial, HabitState.missed];
    } else {
      return [HabitState.none, HabitState.completed, HabitState.missed];
    }
  }

  String _getStateDisplayName(HabitState state) {
    switch (state) {
      case HabitState.none:
        return 'Not tracked';
      case HabitState.onTime:
        return 'On time';
      case HabitState.delayed:
        return 'Delayed';
      case HabitState.partial:
        return 'Partial';
      case HabitState.completed:
        return 'Completed';
      case HabitState.missed:
        return 'Missed';
      case HabitState.avoided:
        return 'Avoided (Good!)';
    }
  }

  int _getDailyScore(int dayIndex) {
    int score = 0;
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    
    for (String habit in _habitStatePoints.keys) {
      bool isPrayer = _prayerHabits.contains(habit);
      bool isDisabled = !isPrayer && isWeekend; // Only disable non-prayer habits on weekends
      
      if (!isDisabled) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state != HabitState.none) {
          score += _habitStatePoints[habit]?[state] ?? 0;
        }
      }
    }
    return score;
  }

  int _getMaxDailyScore() {
    int weekdayMaxScore = 0;
    int weekendMaxScore = 0;
    
    for (String habit in _habitStatePoints.keys) {
      Map<HabitState, int> statePoints = _habitStatePoints[habit]!;
      int maxHabitPoints = statePoints.values.fold(0, (max, points) => points > max ? points : max);
      
      bool isPrayer = _prayerHabits.contains(habit);
      if (isPrayer) {
        weekendMaxScore += maxHabitPoints;
      } else {
        weekdayMaxScore += maxHabitPoints;
        weekendMaxScore += maxHabitPoints;
      }
    }
    
    return weekdayMaxScore; // Return weekday max as baseline
  }

  int _getMaxDailyScoreForDay(int dayIndex) {
    int maxScore = 0;
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    
    for (String habit in _habitStatePoints.keys) {
      bool isPrayer = _prayerHabits.contains(habit);
      bool isDisabled = !isPrayer && isWeekend; // Only disable non-prayer habits on weekends
      
      if (!isDisabled) {
        Map<HabitState, int> statePoints = _habitStatePoints[habit]!;
        int maxHabitPoints = statePoints.values.fold(0, (max, points) => points > max ? points : max);
        maxScore += maxHabitPoints;
      }
    }
    return maxScore;
  }

  double _getDailyPercentage(int dayIndex) {
    int dailyScore = _getDailyScore(dayIndex);
    int maxScore = _getMaxDailyScoreForDay(dayIndex);
    return maxScore > 0 ? dailyScore / maxScore : 0.0;
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 0.9) return Colors.green.shade800;
    if (percentage >= 0.75) return Colors.green.shade600;
    if (percentage >= 0.5) return Colors.green.shade400;
    if (percentage >= 0.25) return Colors.green.shade200;
    if (percentage > 0) return Colors.green.shade100;
    return Colors.grey.shade200;
  }

  int _getHabitWeeklyScore(String habit) {
    int score = 0;
    bool isPrayer = _prayerHabits.contains(habit);
    
    for (int day = 0; day < 7; day++) {
      bool isWeekend = day == 5 || day == 6;
      bool isDisabled = !isPrayer && isWeekend; // Only disable non-prayer habits on weekends
      
      if (!isDisabled) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[day] ?? HabitState.none;
        if (state != HabitState.none) {
          score += _habitStatePoints[habit]?[state] ?? 0;
        }
      }
    }
    return score;
  }

  Color _getStateColor(HabitState state) {
    switch (state) {
      case HabitState.none:
        return Colors.grey.shade200;
      case HabitState.onTime:
      case HabitState.completed:
      case HabitState.avoided:
        return Colors.green.shade600;
      case HabitState.delayed:
      case HabitState.partial:
        return Colors.orange.shade400;
      case HabitState.missed:
        return Colors.red.shade400;
    }
  }

  Widget _getStateIcon(HabitState state) {
    switch (state) {
      case HabitState.none:
        return const SizedBox.shrink();
      case HabitState.onTime:
        return const Icon(Icons.access_time, color: Colors.white, size: 16);
      case HabitState.completed:
        return const Icon(Icons.check, color: Colors.white, size: 16);
      case HabitState.delayed:
        return const Icon(Icons.schedule, color: Colors.white, size: 16);
      case HabitState.partial:
        return const Icon(Icons.circle_outlined, color: Colors.white, size: 16);
      case HabitState.missed:
        return const Icon(Icons.close, color: Colors.white, size: 16);
      case HabitState.avoided:
        return const Icon(Icons.block, color: Colors.white, size: 16);
    }
  }

  int _getWeeklyTotal() {
    int total = 0;
    for (int day = 0; day < 7; day++) {
      total += _getDailyScore(day);
    }
    return total;
  }

  int _getMaxWeeklyScore() {
    int total = 0;
    for (int day = 0; day < 7; day++) {
      total += _getMaxDailyScoreForDay(day);
    }
    return total;
  }

  int _getMaxHabitPoints(String habit) {
    Map<HabitState, int>? statePoints = _habitStatePoints[habit];
    if (statePoints == null) return 0;
    return statePoints.values.fold(0, (max, points) => points > max ? points : max);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _shouldShowContributionGraph()
          ? Column(
              children: [
                _buildContributionGraph(),
                Expanded(child: _buildCurrentView()),
              ],
            )
          : _buildCurrentView(),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _ringAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _ringAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ringAnimationController,
      curve: Curves.easeInOutQuart,
    ));
    
    // Start animations
    _progressAnimationController.forward();
    _ringAnimationController.forward();
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _ringAnimationController.dispose();
    super.dispose();
  }

  void _animateProgressUpdate() {
    _progressAnimationController.reset();
    _ringAnimationController.reset();
    _progressAnimationController.forward();
    _ringAnimationController.forward();
  }

  bool _shouldShowContributionGraph() {
    return false; // Hidden for now
  }

  DateTime _getWeekStart(DateTime date) {
    int daysFromMonday = (date.weekday - 1) % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromMonday));
  }

  String _getWeekKey(DateTime weekStart) {
    return '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  String get _currentWeekKey => _getWeekKey(_currentWeekStart);

  void _goToPreviousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
  }

  void _goToCurrentWeek() {
    setState(() {
      _currentWeekStart = _getWeekStart(DateTime.now());
    });
  }

  PreferredSizeWidget _buildAppBar() {
    String title = _getViewTitle();
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      actions: [
        if (_currentView == ViewType.week) ...[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _goToPreviousWeek,
            tooltip: 'Previous Week',
          ),
          if (!_isCurrentWeek())
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _goToCurrentWeek,
              tooltip: 'Current Week',
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _goToNextWeek,
            tooltip: 'Next Week',
          ),
          const SizedBox(width: 8),
        ],
        _buildViewSelector(),
        const SizedBox(width: 16),
      ],
    );
  }

  String _getViewTitle() {
    switch (_currentView) {
      case ViewType.day:
        return 'Today • ${_formatDate(_selectedDate)}';
      case ViewType.week:
        DateTime weekEnd = _currentWeekStart.add(const Duration(days: 6));
        bool isCurrentWeek = _isCurrentWeek();
        if (isCurrentWeek) {
          return 'This Week';
        } else {
          return '${_formatDate(_currentWeekStart)} - ${_formatDate(weekEnd)}';
        }
      case ViewType.month:
        return 'This Month';
      case ViewType.year:
        return 'This Year';
    }
  }

  bool _isCurrentWeek() {
    DateTime currentWeekStart = _getWeekStart(DateTime.now());
    return _currentWeekStart.isAtSameMomentAs(currentWeekStart);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildViewSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ViewType.values.map((view) {
          bool isSelected = view == _currentView;
          return GestureDetector(
            onTap: () => setState(() => _currentView = view),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getViewName(view),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getViewName(ViewType view) {
    switch (view) {
      case ViewType.day:
        return 'Day';
      case ViewType.week:
        return 'Week';
      case ViewType.month:
        return 'Month';
      case ViewType.year:
        return 'Year';
    }
  }

  Widget _buildContributionGraph() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade300,
                ),
              ),
              _buildContributionLegend(),
            ],
          ),
          const SizedBox(height: 16),
          _buildMonthLabels(),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildDayLabels(),
              const SizedBox(width: 8),
              Expanded(child: _buildContributionGrid()),
            ],
          ),
          const SizedBox(height: 12),
          _buildContributionStats(),
        ],
      ),
    );
  }

  Widget _buildContributionLegend() {
    return Row(
      children: [
        Text(
          'Less',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          return Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _getContributionColor(index / 4),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          'More',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Color _getContributionColor(double intensity) {
    if (intensity == 0) return Colors.grey.shade800;
    if (intensity <= 0.25) return const Color(0xFF0E4429);
    if (intensity <= 0.5) return const Color(0xFF006D32);
    if (intensity <= 0.75) return const Color(0xFF26A641);
    return const Color(0xFF39D353);
  }

  Widget _buildMonthLabels() {
    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: (7 * 20) - 1));
    
    List<String> monthLabels = [];
    Set<int> addedMonths = {};
    
    for (int week = 0; week < 20; week++) {
      DateTime weekStart = startDate.add(Duration(days: week * 7));
      int month = weekStart.month;
      
      if (!addedMonths.contains(month) && week % 4 == 0) {
        monthLabels.add(_getMonthName(month));
        addedMonths.add(month);
      } else {
        monthLabels.add('');
      }
    }
    
    return SizedBox(
      height: 16,
      child: Row(
        children: monthLabels.asMap().entries.map((entry) {
          return SizedBox(
            width: 12, // Match week width including margin
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  Widget _buildDayLabels() {
    const dayLabels = ['Mon', '', 'Wed', '', 'Fri', '', ''];
    
    return SizedBox(
      width: 24,
      height: 80,
      child: Column(
        children: dayLabels.map((label) {
          return Container(
            height: 10,
            margin: const EdgeInsets.only(bottom: 1),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContributionGrid() {
    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: (7 * 20) - 1)); // ~20 weeks
    
    List<List<DateTime>> weeks = [];
    DateTime currentWeekStart = startDate.subtract(Duration(days: startDate.weekday - 1));
    
    for (int week = 0; week < 20; week++) {
      List<DateTime> weekDays = [];
      for (int day = 0; day < 7; day++) {
        weekDays.add(currentWeekStart.add(Duration(days: (week * 7) + day)));
      }
      weeks.add(weekDays);
    }

    return SizedBox(
      height: 80,
      child: Row(
        children: weeks.map((week) {
          return Container(
            margin: const EdgeInsets.only(right: 2),
            child: Column(
              children: week.map((date) {
                bool isFuture = date.isAfter(now);
                double intensity = isFuture ? 0 : _getDateIntensity(date);
                
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(bottom: 1),
                  decoration: BoxDecoration(
                    color: isFuture 
                        ? Colors.grey.shade800.withValues(alpha: 0.3)
                        : _getContributionColor(intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  double _getDateIntensity(DateTime date) {
    // For now, simulate data - in a real app this would pull from your data store
    int dayIndex = date.weekday == 7 ? 0 : date.weekday;
    int currentScore = _getDailyScore(dayIndex); // Using current week's data as simulation
    int maxScore = _getMaxDailyScoreForDay(dayIndex);
    
    if (maxScore == 0) return 0.0;
    return (currentScore / maxScore).clamp(0.0, 1.0);
  }

  Widget _buildContributionStats() {
    return Row(
      children: [
        Text(
          'Total activity in the last year',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const Spacer(),
        Text(
          _getActivitySummary(),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getActivitySummary() {
    int activeDays = _getActiveDaysCount();
    int currentStreak = _getCurrentStreak();
    return '$activeDays active days • $currentStreak day streak';
  }

  int _getActiveDaysCount() {
    // Simulate active days count
    int totalDays = 0;
    for (int day = 0; day < 7; day++) {
      if (_getDailyScore(day) > 0) totalDays++;
    }
    return totalDays * 20; // Simulate for ~20 weeks
  }

  int _getCurrentStreak() {
    // Simulate current streak
    int streak = 0;
    for (int day = 6; day >= 0; day--) {
      if (_getDailyScore(day) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case ViewType.day:
        return _buildDayView();
      case ViewType.week:
        return _buildWeekView();
      case ViewType.month:
        return _buildMonthView();
      case ViewType.year:
        return _buildYearView();
    }
  }

  Widget _buildDayView() {
    int todayIndex = _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday; // Convert to our 0-6 system
    int currentScore = _getDailyScore(todayIndex);
    int maxScore = _getMaxDailyScoreForDay(todayIndex);
    double percentage = maxScore > 0 ? currentScore / maxScore : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAppleStyleActivityRings(todayIndex),
        const SizedBox(height: 32),
        _buildAppleStyleDailyProgress(currentScore, maxScore, percentage),
        const SizedBox(height: 24),
        ..._buildAppleStyleHabitSections(todayIndex),
      ],
    );
  }

  Widget _buildDailyScoreCard(int current, int max, double percentage) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade300,
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$current / $max points',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.secondary,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDailyHabitSections(int dayIndex) {
    List<Widget> sections = [];
    
    for (var entry in _categories.entries) {
      sections.add(_buildDailyHabitSection(entry.key, entry.value, dayIndex));
      sections.add(const SizedBox(height: 16));
    }
    
    return sections;
  }

  Widget _buildDailyHabitSection(String categoryName, List<String> habits, int dayIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              categoryName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          ...habits.map((habit) => _buildDailyHabitItem(habit, dayIndex)),
        ],
      ),
    );
  }

  Widget _buildDailyHabitItem(String habit, int dayIndex) {
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    bool isPrayer = _prayerHabits.contains(habit);
    bool isDisabled = !isPrayer && isWeekend;
    bool isSleepTracking = _sleepTrackingHabits.contains(habit);
    
    HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
    int points = _habitStatePoints[habit]?[state] ?? 0;
    int maxPoints = _getMaxHabitPoints(habit);
    TimeOfDay? time = _timeData[habit]?[_currentWeekKey]?[dayIndex];
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: isDisabled ? null : () => _showHabitStateDialog(habit, dayIndex),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey.shade700 : _getStateColor(state),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isDisabled 
                ? Icon(Icons.remove, color: Colors.grey.shade500, size: 16)
                : _getStateIcon(state),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              habit,
              style: TextStyle(
                color: isDisabled ? Colors.grey.shade600 : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSleepTracking && time != null)
              Text(
                time.format(context),
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              state != HabitState.none ? '+$points' : '$maxPoints',
              style: TextStyle(
                color: state != HabitState.none 
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (state == HabitState.none)
              Text(
                'pts',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWeeklySummaryCard(),
        const SizedBox(height: 24),
        ..._categories.entries.map((entry) {
          return Column(
            children: [
              _buildWeekCategorySection(entry.key, entry.value),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWeeklySummaryCard() {
    int weeklyTotal = _getWeeklyTotal();
    int maxWeeklyTotal = _getMaxWeeklyScore();
    double weeklyPercentage = maxWeeklyTotal > 0 ? weeklyTotal / maxWeeklyTotal : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade300,
                ),
              ),
              Text(
                '${(weeklyPercentage * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$weeklyTotal / $maxWeeklyTotal points',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _buildWeeklyDailySummary(),
        ],
      ),
    );
  }

  Widget _buildWeeklyDailySummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Day',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ),
              ..._weekDays.asMap().entries.map((entry) {
                return Expanded(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Score',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ),
              ...List.generate(7, (dayIndex) {
                int score = _getDailyScore(dayIndex);
                double percentage = _getDailyPercentage(dayIndex);
                
                return Expanded(
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _getScoreColor(percentage),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCategorySection(String categoryName, List<String> habits) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              categoryName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          _buildWeekHabitGrid(habits),
        ],
      ),
    );
  }

  Widget _buildWeekHabitGrid(List<String> habits) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade800, width: 0.5),
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(1),
          6: FlexColumnWidth(1),
          7: FlexColumnWidth(1),
          8: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade900),
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Habit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              ..._weekDays.map((day) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
              )),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
              ),
            ],
          ),
          ...habits.map((habit) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit, style: const TextStyle(color: Colors.white)),
                    Text(
                      '(${_getMaxHabitPoints(habit)} pts max)',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              ...List.generate(7, (dayIndex) {
                bool isWeekend = dayIndex == 5 || dayIndex == 6;
                bool isPrayer = _prayerHabits.contains(habit);
                bool isDisabled = !isPrayer && isWeekend;
                
                HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
                
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: GestureDetector(
                    onTap: isDisabled ? null : () => _showHabitStateDialog(habit, dayIndex),
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDisabled ? Colors.grey.shade700 : _getStateColor(state),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isDisabled 
                          ? Icon(Icons.remove, color: Colors.grey.shade500, size: 16)
                          : _getStateIcon(state),
                    ),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${_getHabitWeeklyScore(habit)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildMonthView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'Month View',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Heatmap calendar coming soon',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'Year View',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'GitHub-style contribution graph coming soon',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummary() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Summary',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Total: ${_getWeeklyTotal()} / ${_getMaxWeeklyScore()} pts',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${((_getWeeklyTotal() / _getMaxWeeklyScore()) * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 16, color: Colors.green.shade700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDailySummaryGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummaryGrid() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Day', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._weekDays.map((day) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            )),
          ],
        ),
        TableRow(
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...List.generate(7, (dayIndex) {
              int score = _getDailyScore(dayIndex);
              double percentage = _getDailyPercentage(dayIndex);
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getScoreColor(percentage),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '${(percentage * 100).toInt()}%',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySection(String categoryName, List<String> habits) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildHabitGrid(habits),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitGrid(List<String> habits) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1),
        6: FlexColumnWidth(1),
        7: FlexColumnWidth(1),
        8: FlexColumnWidth(1.2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Habit (pts)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._weekDays.map((day) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            )),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Week', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ],
        ),
        ...habits.map((habit) => TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit),
                  Text(
                    '(${_getMaxHabitPoints(habit)} pts max)',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            ...List.generate(7, (dayIndex) {
              bool isWeekend = dayIndex == 5 || dayIndex == 6; // Saturday (5) and Sunday (6)
              bool isPrayer = _prayerHabits.contains(habit);
              bool isDisabled = !isPrayer && isWeekend; // Only disable non-prayer habits on weekends
              
              HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
              
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: GestureDetector(
                  onTap: isDisabled ? null : () => _showHabitStateDialog(habit, dayIndex),
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDisabled ? Colors.grey.shade100 : _getStateColor(state),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isDisabled 
                        ? Icon(Icons.remove, color: Colors.grey.shade400, size: 16)
                        : _getStateIcon(state),
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '${_getHabitWeeklyScore(habit)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        )),
      ],
    );
  }

  // Apple-style Activity Rings Widget
  Widget _buildAppleStyleActivityRings(int dayIndex) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF161B22).withValues(alpha: 0.95),
            const Color(0xFF0D1117).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Today\'s Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            width: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) => _buildActivityRing(
                    radius: 85,
                    strokeWidth: 12,
                    progress: _getCategoryProgress('Akhira (Salah)', dayIndex) * _ringAnimation.value,
                    color: const Color(0xFFFF453A), // Red ring
                  ),
                ),
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) => _buildActivityRing(
                    radius: 65,
                    strokeWidth: 12,
                    progress: _getCategoryProgress('Daily Habits', dayIndex) * _ringAnimation.value,
                    color: const Color(0xFF30D158), // Green ring
                  ),
                ),
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) => _buildActivityRing(
                    radius: 45,
                    strokeWidth: 12,
                    progress: _getCategoryProgress('Sleep Metrics', dayIndex) * _ringAnimation.value,
                    color: const Color(0xFF007AFF), // Blue ring
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_getDailyScore(dayIndex)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'POINTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildRingLegend(),
        ],
      ),
    );
  }

  Widget _buildActivityRing({
    required double radius,
    required double strokeWidth,
    required double progress,
    required Color color,
  }) {
    return CustomPaint(
      size: Size(radius * 2, radius * 2),
      painter: ActivityRingPainter(
        progress: progress,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }

  Widget _buildRingLegend() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) => _buildLegendItem(
            color: const Color(0xFFFF453A),
            title: 'Prayers',
            subtitle: '${(_getCategoryProgress('Akhira (Salah)', _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday) * _ringAnimation.value * 100).toInt()}% complete',
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) => _buildLegendItem(
            color: const Color(0xFF30D158),
            title: 'Daily Habits',
            subtitle: '${(_getCategoryProgress('Daily Habits', _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday) * _ringAnimation.value * 100).toInt()}% complete',
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) => _buildLegendItem(
            color: const Color(0xFF007AFF),
            title: 'Sleep',
            subtitle: '${(_getCategoryProgress('Sleep Metrics', _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday) * _ringAnimation.value * 100).toInt()}% complete',
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getCategoryProgress(String categoryName, int dayIndex) {
    List<String> habits = _categories[categoryName] ?? [];
    int currentScore = 0;
    int maxScore = 0;
    
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    
    for (String habit in habits) {
      bool isPrayer = _prayerHabits.contains(habit);
      bool isDisabled = !isPrayer && isWeekend;
      
      if (!isDisabled) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state != HabitState.none) {
          currentScore += _habitStatePoints[habit]?[state] ?? 0;
        }
        maxScore += _getMaxHabitPoints(habit);
      }
    }
    
    return maxScore > 0 ? currentScore / maxScore : 0.0;
  }

  Widget _buildAppleStyleDailyProgress(int current, int max, double percentage) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF161B22).withValues(alpha: 0.95),
            const Color(0xFF0D1117).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF30D158).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${(percentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF30D158),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$current / $max points',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) => FractionallySizedBox(
                widthFactor: percentage * _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF30D158), Color(0xFF32D74B)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppleStyleHabitSections(int dayIndex) {
    List<Widget> sections = [];
    
    for (var entry in _categories.entries) {
      sections.add(_buildAppleStyleHabitSection(entry.key, entry.value, dayIndex));
      sections.add(const SizedBox(height: 20));
    }
    
    return sections;
  }

  Widget _buildAppleStyleHabitSection(String categoryName, List<String> habits, int dayIndex) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF161B22).withValues(alpha: 0.95),
            const Color(0xFF0D1117).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              categoryName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          ...habits.map((habit) => _buildAppleStyleHabitItem(habit, dayIndex)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAppleStyleHabitItem(String habit, int dayIndex) {
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    bool isPrayer = _prayerHabits.contains(habit);
    bool isDisabled = !isPrayer && isWeekend;
    bool isSleepTracking = _sleepTrackingHabits.contains(habit);
    
    HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
    int points = _habitStatePoints[habit]?[state] ?? 0;
    int maxPoints = _getMaxHabitPoints(habit);
    TimeOfDay? time = _timeData[habit]?[_currentWeekKey]?[dayIndex];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: isDisabled ? null : () => _showHabitStateDialog(habit, dayIndex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDisabled ? Colors.white.withValues(alpha: 0.1) : _getAppleStateColor(state),
              borderRadius: BorderRadius.circular(8),
              boxShadow: state != HabitState.none && !isDisabled ? [
                BoxShadow(
                  color: _getAppleStateColor(state).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: isDisabled 
                ? Icon(Icons.remove, color: Colors.white.withValues(alpha: 0.3), size: 18)
                : _getAppleStateIcon(state),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              habit,
              style: TextStyle(
                color: isDisabled ? Colors.white.withValues(alpha: 0.4) : Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            if (isSleepTracking && time != null)
              Text(
                time.format(context),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: state != HabitState.none 
                ? const Color(0xFF30D158).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: state != HabitState.none 
                  ? const Color(0xFF30D158).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            state != HabitState.none ? '+$points' : '$maxPoints',
            style: TextStyle(
              color: state != HabitState.none 
                  ? const Color(0xFF30D158)
                  : Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Color _getAppleStateColor(HabitState state) {
    switch (state) {
      case HabitState.none:
        return Colors.white.withValues(alpha: 0.15);
      case HabitState.onTime:
      case HabitState.completed:
      case HabitState.avoided:
        return const Color(0xFF30D158);
      case HabitState.delayed:
      case HabitState.partial:
        return const Color(0xFFFF9F0A);
      case HabitState.missed:
        return const Color(0xFFFF453A);
    }
  }

  Widget _getAppleStateIcon(HabitState state) {
    switch (state) {
      case HabitState.none:
        return const SizedBox.shrink();
      case HabitState.onTime:
        return const Icon(Icons.schedule, color: Colors.white, size: 18);
      case HabitState.completed:
        return const Icon(Icons.check_circle, color: Colors.white, size: 18);
      case HabitState.delayed:
        return const Icon(Icons.access_time, color: Colors.white, size: 18);
      case HabitState.partial:
        return const Icon(Icons.circle_outlined, color: Colors.white, size: 18);
      case HabitState.missed:
        return const Icon(Icons.cancel, color: Colors.white, size: 18);
      case HabitState.avoided:
        return const Icon(Icons.block, color: Colors.white, size: 18);
    }
  }
}

// Custom Painter for Activity Rings
class ActivityRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  ActivityRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Background ring
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Start at top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

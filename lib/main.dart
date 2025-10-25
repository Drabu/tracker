import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:html' as html show window;
import 'dart:js' as js;

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
  DateTime _selectedDate = DateTime.now();
  DateTime _currentWeekStart = DateTime.now();
  final Map<String, Map<String, Map<int, HabitState>>> _trackingData = {}; // habit -> weekKey -> dayIndex -> state
  final Map<String, Map<String, Map<int, TimeOfDay?>>> _timeData = {}; // habit -> weekKey -> dayIndex -> time
  
  late AnimationController _progressAnimationController;
  late AnimationController _ringAnimationController;
  late AnimationController _compoundProgressAnimationController;
  late AnimationController _categoryProgressAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _ringAnimation;
  late Animation<double> _compoundProgressAnimation;
  late Animation<double> _categoryProgressAnimation;
  
  Timer? _dayUpdateTimer;
  Timer? _screenKeepAliveTimer;
  
  // Value notifiers for granular updates
  final ValueNotifier<int> _pointsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _compoundProgressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<Map<String, double>> _categoryProgressNotifier = ValueNotifier<Map<String, double>>({});

  final List<String> _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  final Map<String, List<String>> _categories = {
    'Deen': [
      'Quran',
      'Fajr',
      'Duhr',
      'Asr',
      'Maghrib',
      'Isha',
      'Evening Quran',
    ],
    'Personal': [
      'Guitar',
      'Bar Chord',
      'Fingerstyle',
      'Random',
      'Book',
      'Walk',
    ],
    'Professional': [
      'Typing',
      'Data Structures',
    ],
    'Health': [
      'Breakfast',
      'Eggs',
      'Meal',
      'Coffee',
      'Cold Shower',
      'Gym',
      'Mid Day Shower',
      'Water',
    ],
    'Sleep Tracking': [
      'Bed Time',
      'Sleep Time', 
      'Mid Day Sleep',
      'Wake Time (W.T.)',
    ],
  };

  final Set<String> _prayerHabits = {
    'Fajr', 'Duhr', 'Asr', 'Maghrib', 'Isha'
  };

  final Set<String> _timeBasedHabits = {
    'Fajr', 'Duhr', 'Asr', 'Maghrib', 'Isha', 'Gym', 'Bed Time', 'Sleep Time', 'Wake Time (W.T.)'
  };

  final Set<String> _sleepTrackingHabits = {
    'Bed Time', 'Sleep Time', 'Mid Day Sleep', 'Wake Time (W.T.)'
  };

  final Set<String> _compoundingHabits = {
    'Quran', 'Fajr', 'Duhr', 'Asr', 'Maghrib', 'Isha', 'Evening Quran', // Deen
    'Guitar', 'Book', // Personal  
    'Typing', 'Data Structures', // Professional
    'Gym', 'Water' // Health
  };

  // Development mode flag - set to true to enable all habits on weekends
  static const bool _isDevelopmentMode = true;

  bool _isHabitDisabled(String habit, int dayIndex) {
    if (_isDevelopmentMode) return false; // Never disable habits in dev mode
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    bool isPrayer = _prayerHabits.contains(habit);
    return !isPrayer && isWeekend; // Only disable non-prayer habits on weekends
  }


  final Map<String, Map<HabitState, int>> _habitStatePoints = {
    'Fajr': {HabitState.onTime: 30, HabitState.delayed: 20, HabitState.missed: 0},
    'Duhr': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Asr': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Maghrib': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Isha': {HabitState.onTime: 15, HabitState.delayed: 10, HabitState.missed: 0},
    'Quran': {HabitState.completed: 15, HabitState.partial: 8, HabitState.missed: 0},
    'Evening Quran': {HabitState.completed: 15, HabitState.partial: 8, HabitState.missed: 0},
    'Guitar': {HabitState.completed: 10, HabitState.partial: 5, HabitState.missed: 0},
    'Bar Chord': {HabitState.completed: 8, HabitState.partial: 4, HabitState.missed: 0},
    'Fingerstyle': {HabitState.completed: 8, HabitState.partial: 4, HabitState.missed: 0},
    'Random': {HabitState.completed: 5, HabitState.partial: 3, HabitState.missed: 0},
    'Book': {HabitState.completed: 15, HabitState.partial: 8, HabitState.missed: 0},
    'Walk': {HabitState.completed: 10, HabitState.partial: 5, HabitState.missed: 0},
    'Typing': {HabitState.completed: 10, HabitState.partial: 5, HabitState.missed: 0},
    'Data Structures': {HabitState.completed: 15, HabitState.partial: 8, HabitState.missed: 0},
    'Breakfast': {HabitState.completed: 5, HabitState.missed: 0},
    'Eggs': {HabitState.completed: 3, HabitState.missed: 0},
    'Meal': {HabitState.completed: 3, HabitState.missed: 0},
    'Coffee': {HabitState.completed: 2, HabitState.missed: 0},
    'Cold Shower': {HabitState.completed: 20, HabitState.missed: 0},
    'Gym': {HabitState.completed: 25, HabitState.partial: 15, HabitState.missed: 0},
    'Mid Day Shower': {HabitState.completed: 10, HabitState.missed: 0},
    'Water': {HabitState.completed: 5, HabitState.partial: 3, HabitState.missed: 0},
    'Bed Time': {HabitState.onTime: 5, HabitState.delayed: 2, HabitState.missed: 0},
    'Sleep Time': {HabitState.onTime: 8, HabitState.delayed: 4, HabitState.missed: 0},
    'Mid Day Sleep': {HabitState.avoided: 5, HabitState.completed: 2, HabitState.missed: 0},
    'Wake Time (W.T.)': {HabitState.onTime: 5, HabitState.delayed: 2, HabitState.missed: 0},
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
              int points = _getHabitPoints(habit, state, dayIndex);
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
                      _updateHabitState(habit, dayIndex, state, selectedTime);
                      _saveData(); // Save data after changes
                    }
                  } else {
                    _updateHabitState(habit, dayIndex, state, null);
                    _saveData(); // Save data after changes
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
    if (habit == 'Mid Day Sleep') {
      return [HabitState.none, HabitState.avoided, HabitState.completed, HabitState.missed];
    } else if (_prayerHabits.contains(habit)) {
      return [HabitState.none, HabitState.onTime, HabitState.delayed, HabitState.missed];
    } else if (_timeBasedHabits.contains(habit)) {
      return [HabitState.none, HabitState.onTime, HabitState.delayed, HabitState.missed];
    } else if (['Quran', 'Evening Quran', 'Book', 'Gym', 'Walk', 'Typing', 'Data Structures', 'Water', 'Guitar'].contains(habit)) {
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


  int _getHabitPoints(String habit, HabitState state, int dayIndex) {
    return _habitStatePoints[habit]?[state] ?? 0;
  }

  int _getDailyScore(int dayIndex) {
    int score = 0;
    
    for (String habit in _habitStatePoints.keys) {
      if (!_isHabitDisabled(habit, dayIndex)) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state != HabitState.none) {
          score += _getHabitPoints(habit, state, dayIndex);
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
    
    for (String habit in _habitStatePoints.keys) {
      if (!_isHabitDisabled(habit, dayIndex)) {
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
    
    for (int day = 0; day < 7; day++) {
      if (!_isHabitDisabled(habit, day)) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[day] ?? HabitState.none;
        if (state != HabitState.none) {
          score += _getHabitPoints(habit, state, day);
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
    return GestureDetector(
      onTap: () {
        // Re-enable wake lock on user interaction (required by many browsers)
        if (_currentView == ViewType.day) {
          _tryWebWakeLock();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _shouldShowContributionGraph()
            ? Column(
                children: [
                  _buildContributionGraph(),
                  Expanded(child: _buildCurrentView()),
                ],
              )
            : _buildCurrentView(),
      ),
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
    
    _compoundProgressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _categoryProgressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    
    _compoundProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _compoundProgressAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _categoryProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _categoryProgressAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    // Enable wake lock to keep screen on
    _enableWakeLock();
    
    // Set up timer to update current day at midnight
    _setupDayUpdateTimer();
    
    // Load saved data and start animations
    _loadData().then((_) {
      if (mounted) {
        // Initialize notifiers with current values
        int currentDayIndex = DateTime.now().weekday - 1;
        _pointsNotifier.value = _getDailyScore(currentDayIndex);
        _compoundProgressNotifier.value = _getCompoundProgress(currentDayIndex);
        
        Map<String, double> categoryProgress = {};
        for (String categoryName in _categories.keys) {
          categoryProgress[categoryName] = _getCategoryProgress(categoryName, currentDayIndex);
        }
        _categoryProgressNotifier.value = categoryProgress;
        
        setState(() {});
        _progressAnimationController.forward();
        _ringAnimationController.forward();
        _compoundProgressAnimationController.forward();
        _categoryProgressAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _dayUpdateTimer?.cancel();
    _screenKeepAliveTimer?.cancel();
    _progressAnimationController.dispose();
    _ringAnimationController.dispose();
    _compoundProgressAnimationController.dispose();
    _categoryProgressAnimationController.dispose();
    _pointsNotifier.dispose();
    _compoundProgressNotifier.dispose();
    _categoryProgressNotifier.dispose();
    _disableWakeLock();
    super.dispose();
  }

  void _animateProgressUpdate() {
    _progressAnimationController.reset();
    _ringAnimationController.reset();
    _progressAnimationController.forward();
    _ringAnimationController.forward();
  }

  void _updateHabitState(String habit, int dayIndex, HabitState state, TimeOfDay? selectedTime) {
    // Update habit data without setState
    _trackingData[habit] ??= {};
    _trackingData[habit]![_currentWeekKey] ??= {};
    _trackingData[habit]![_currentWeekKey]![dayIndex] = state;
    
    // Handle time data
    if (selectedTime != null) {
      _timeData[habit] ??= {};
      _timeData[habit]![_currentWeekKey] ??= {};
      _timeData[habit]![_currentWeekKey]![dayIndex] = selectedTime;
    } else if (state == HabitState.none || state == HabitState.missed) {
      _timeData[habit] ??= {};
      _timeData[habit]![_currentWeekKey] ??= {};
      _timeData[habit]![_currentWeekKey]![dayIndex] = null;
    }
    
    // Update specific progress values
    _updateProgressNotifiers(habit);
    _animateSpecificProgress(habit);
  }

  void _updateProgressNotifiers(String habit) {
    // Update points notifier
    int currentDayIndex = DateTime.now().weekday - 1;
    _pointsNotifier.value = _getDailyScore(currentDayIndex);
    
    // Always update compound progress (even if this specific habit isn't compounding,
    // the overall count affects the percentage)
    _compoundProgressNotifier.value = _getCompoundProgress(currentDayIndex);
    
    // Update category progress for all categories (since we don't know which category changed)
    Map<String, double> categoryProgress = {};
    for (String categoryName in _categories.keys) {
      categoryProgress[categoryName] = _getCategoryProgress(categoryName, currentDayIndex);
    }
    _categoryProgressNotifier.value = categoryProgress;
    
    // Trigger a setState for habit grids to update immediately  
    setState(() {});
  }

  double _getCompoundProgress(int dayIndex) {
    List<String> compoundHabits = _compoundingHabits.toList();
    int completedCount = 0;
    int totalCount = 0;
    
    for (String habit in compoundHabits) {
      if (!_isHabitDisabled(habit, dayIndex)) {
        totalCount++;
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state == HabitState.completed || state == HabitState.onTime || state == HabitState.partial) {
          completedCount++;
        }
      }
    }
    
    return totalCount > 0 ? completedCount / totalCount : 0.0;
  }

  double _getCategoryProgress(String categoryName, int dayIndex) {
    List<String> habits = _categories[categoryName] ?? [];
    int completed = 0;
    int total = 0;
    
    for (String habit in habits) {
      if (!_isHabitDisabled(habit, dayIndex)) {
        total++;
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state == HabitState.completed || state == HabitState.onTime || state == HabitState.partial) {
          completed++;
        }
      }
    }
    
    return total > 0 ? completed / total : 0.0;
  }

  void _animateSpecificProgress(String habitName) {
    // Determine which progress sections need to update based on the habit
    bool updateCompound = _compoundingHabits.contains(habitName);
    bool updateCategory = true; // Categories always update since every habit belongs to one
    
    if (updateCompound) {
      _compoundProgressAnimationController.reset();
      _compoundProgressAnimationController.forward();
    }
    
    if (updateCategory) {
      _categoryProgressAnimationController.reset();
      _categoryProgressAnimationController.forward();
    }
    
    // Always update the main progress (points display)
    _progressAnimationController.reset();
    _progressAnimationController.forward();
  }

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      print('Wake lock enabled - screen will stay on');
    } catch (e) {
      print('Failed to enable wake lock: $e');
    }
    
    // Try web-specific Screen Wake Lock API
    _tryWebWakeLock();
    
    // Start fallback method
    _startScreenKeepAlive();
  }

  void _tryWebWakeLock() {
    try {
      // Try to use the Screen Wake Lock API directly
      js.context.callMethod('eval', ['''
        if ('wakeLock' in navigator) {
          navigator.wakeLock.request('screen').then(function(wakeLock) {
            console.log('Screen Wake Lock enabled');
            window.wakeLockSentinel = wakeLock;
          }).catch(function(error) {
            console.log('Screen Wake Lock failed:', error);
          });
        } else {
          console.log('Screen Wake Lock API not supported');
        }
      ''']);
    } catch (e) {
      print('Web wake lock failed: $e');
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      print('Wake lock disabled');
    } catch (e) {
      print('Failed to disable wake lock: $e');
    }
    
    // Disable web wake lock
    _disableWebWakeLock();
    
    // Stop fallback method
    _stopScreenKeepAlive();
  }

  void _disableWebWakeLock() {
    try {
      js.context.callMethod('eval', ['''
        if (window.wakeLockSentinel) {
          window.wakeLockSentinel.release();
          window.wakeLockSentinel = null;
          console.log('Screen Wake Lock released');
        }
      ''']);
    } catch (e) {
      print('Failed to release web wake lock: $e');
    }
  }

  void _startScreenKeepAlive() {
    // Additional method to keep screen active on web
    // Trigger a minor UI update every 25 seconds to prevent screen sleep
    _screenKeepAliveTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (mounted && _currentView == ViewType.day) {
        // Multiple fallback methods to keep screen active
        try {
          // Method 1: Trigger very subtle animation
          _ringAnimationController.forward(from: 0.999);
          
          // Method 2: Create invisible video element to prevent sleep
          js.context.callMethod('eval', ['''
            if (!window.keepAliveVideo) {
              var video = document.createElement('video');
              video.src = 'data:video/mp4;base64,AAAAHGZ0eXBtcDQyAAACAEFhdGEBAQAAAREAAAABAAAARAAAaGQAABCkAAAQpAAAAAADCOxPcAAAwBQAAAe8AAAABAAAAAEACo/UgEwEAABGaBgn40AE=';
              video.loop = true;
              video.muted = true;
              video.style.opacity = '0';
              video.style.position = 'absolute';
              video.style.zIndex = '-1';
              document.body.appendChild(video);
              video.play().catch(function(e) { console.log('Video play failed:', e); });
              window.keepAliveVideo = video;
            }
          ''']);
        } catch (e) {
          print('Keep-alive fallback failed: $e');
        }
      }
    });
    print('Enhanced screen keep-alive timer started');
  }

  void _stopScreenKeepAlive() {
    _screenKeepAliveTimer?.cancel();
    _screenKeepAliveTimer = null;
    
    // Clean up video element
    try {
      js.context.callMethod('eval', ['''
        if (window.keepAliveVideo) {
          window.keepAliveVideo.remove();
          window.keepAliveVideo = null;
        }
      ''']);
    } catch (e) {
      print('Failed to clean up keep-alive video: $e');
    }
    
    print('Screen keep-alive timer stopped');
  }

  void _setupDayUpdateTimer() {
    // Calculate time until next midnight
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);

    // Set up initial timer to trigger at midnight
    _dayUpdateTimer = Timer(timeUntilMidnight, () {
      _updateCurrentDay();
      // Set up recurring timer for every 24 hours
      _dayUpdateTimer = Timer.periodic(const Duration(days: 1), (_) {
        _updateCurrentDay();
      });
    });
  }

  void _updateCurrentDay() {
    if (mounted) {
      setState(() {
        _selectedDate = DateTime.now();
        // Update current week if we've moved to a new week
        DateTime newWeekStart = _getWeekStart(DateTime.now());
        if (!newWeekStart.isAtSameMomentAs(_currentWeekStart)) {
          _currentWeekStart = newWeekStart;
        }
      });
      _saveData();
    }
  }

  // Data persistence methods
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert tracking data to JSON-serializable format
      Map<String, dynamic> trackingDataJson = {};
      _trackingData.forEach((habit, weeks) {
        trackingDataJson[habit] = {};
        weeks.forEach((weekKey, days) {
          trackingDataJson[habit][weekKey] = {};
          days.forEach((dayIndex, state) {
            trackingDataJson[habit][weekKey][dayIndex.toString()] = state.index;
          });
        });
      });
      
      // Convert time data to JSON-serializable format
      Map<String, dynamic> timeDataJson = {};
      _timeData.forEach((habit, weeks) {
        timeDataJson[habit] = {};
        weeks.forEach((weekKey, days) {
          timeDataJson[habit][weekKey] = {};
          days.forEach((dayIndex, time) {
            if (time != null) {
              timeDataJson[habit][weekKey][dayIndex.toString()] = {
                'hour': time.hour,
                'minute': time.minute,
              };
            }
          });
        });
      });

      // Save to SharedPreferences
      await prefs.setString('trackingData', jsonEncode(trackingDataJson));
      await prefs.setString('timeData', jsonEncode(timeDataJson));
      await prefs.setString('currentWeekStart', _currentWeekStart.toIso8601String());
      
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load tracking data
      final trackingDataString = prefs.getString('trackingData');
      if (trackingDataString != null) {
        final Map<String, dynamic> trackingDataJson = jsonDecode(trackingDataString);
        _trackingData.clear();
        
        trackingDataJson.forEach((habit, weeks) {
          _trackingData[habit] = {};
          (weeks as Map<String, dynamic>).forEach((weekKey, days) {
            _trackingData[habit]![weekKey] = {};
            (days as Map<String, dynamic>).forEach((dayIndexStr, stateIndex) {
              final dayIndex = int.parse(dayIndexStr);
              final state = HabitState.values[stateIndex as int];
              _trackingData[habit]![weekKey]![dayIndex] = state;
            });
          });
        });
      }
      
      // Load time data
      final timeDataString = prefs.getString('timeData');
      if (timeDataString != null) {
        final Map<String, dynamic> timeDataJson = jsonDecode(timeDataString);
        _timeData.clear();
        
        timeDataJson.forEach((habit, weeks) {
          _timeData[habit] = {};
          (weeks as Map<String, dynamic>).forEach((weekKey, days) {
            _timeData[habit]![weekKey] = {};
            (days as Map<String, dynamic>).forEach((dayIndexStr, timeJson) {
              final dayIndex = int.parse(dayIndexStr);
              final timeMap = timeJson as Map<String, dynamic>;
              final time = TimeOfDay(
                hour: timeMap['hour'] as int,
                minute: timeMap['minute'] as int,
              );
              _timeData[habit]![weekKey]![dayIndex] = time;
            });
          });
        });
      }
      
      // Load current week start
      final weekStartString = prefs.getString('currentWeekStart');
      if (weekStartString != null) {
        _currentWeekStart = DateTime.parse(weekStartString);
      }
      
    } catch (e) {
      print('Error loading data: $e');
    }
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
    _saveData(); // Save current week
  }

  void _goToNextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
    _saveData(); // Save current week
  }

  void _goToCurrentWeek() {
    setState(() {
      _currentWeekStart = _getWeekStart(DateTime.now());
    });
    _saveData(); // Save current week
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
        return 'Today • ${_formatDate(DateTime.now())}';
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
    int dayIndex = date.weekday == 7 ? 6 : date.weekday - 1; // Convert to 0-6 system (Mon=0, Sun=6)
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
    DateTime now = DateTime.now();
    int todayIndex = now.weekday == 7 ? 6 : now.weekday - 1; // Convert to our 0-6 system (Mon=0, Sun=6)
    int currentScore = _getDailyScore(todayIndex);
    int maxScore = _getMaxDailyScoreForDay(todayIndex);
    double percentage = maxScore > 0 ? currentScore / maxScore : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isTablet = constraints.maxWidth > 800;
        
        if (isTablet) {
          return _buildTabletDashboard(todayIndex, currentScore);
        } else {
          return _buildMobileDashboard(todayIndex, currentScore, maxScore, percentage);
        }
      },
    );
  }

  Widget _buildMobileDashboard(int todayIndex, int currentScore, int maxScore, double percentage) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTodaysFocusSection(todayIndex),
        const SizedBox(height: 24),
        _buildYourProgressSection(todayIndex, currentScore),
      ],
    );
  }

  Widget _buildTabletDashboard(int todayIndex, int currentScore) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: _buildTodaysFocusSection(todayIndex),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: _buildInsightsSection(todayIndex, currentScore),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: _buildYourProgressSection(todayIndex, currentScore),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(int dayIndex, int currentScore) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSIGHTS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildAppleFitnessStyleCard(dayIndex),
          const SizedBox(height: 24),
          _buildActivityRingsWidget(dayIndex),
          const SizedBox(height: 24),
          _buildWeeklyStreakCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActivityRingsWidget(int dayIndex) {
    final deenProgress = _getCategoryProgress('Deen', dayIndex);
    final personalProgress = _getCategoryProgress('Personal', dayIndex);
    final healthProgress = _getCategoryProgress('Health', dayIndex);
    final totalProgress = (deenProgress + personalProgress + healthProgress) / 3;
    
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D3A),
            const Color(0xFF1E212E).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'ACTIVITY RINGS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalProgress >= 0.8 
                    ? const Color(0xFF30D158).withValues(alpha: 0.2)
                    : const Color(0xFFFF9F0A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: totalProgress >= 0.8 
                      ? const Color(0xFF30D158).withValues(alpha: 0.4)
                      : const Color(0xFFFF9F0A).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  totalProgress >= 0.8 ? 'EXCELLENT' : 'ON TRACK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: totalProgress >= 0.8 
                      ? const Color(0xFF30D158)
                      : const Color(0xFFFF9F0A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Enhanced rings with glow effect
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF453A).withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 130,
                  width: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _ringAnimation,
                        builder: (context, child) => _buildEnhancedActivityRing(
                          radius: 60,
                          strokeWidth: 9,
                          progress: deenProgress * _ringAnimation.value,
                          color: const Color(0xFFFF453A),
                          glowColor: const Color(0xFFFF453A).withValues(alpha: 0.4),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _ringAnimation,
                        builder: (context, child) => _buildEnhancedActivityRing(
                          radius: 46,
                          strokeWidth: 9,
                          progress: personalProgress * _ringAnimation.value,
                          color: const Color(0xFF30D158),
                          glowColor: const Color(0xFF30D158).withValues(alpha: 0.4),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _ringAnimation,
                        builder: (context, child) => _buildEnhancedActivityRing(
                          radius: 32,
                          strokeWidth: 9,
                          progress: healthProgress * _ringAnimation.value,
                          color: const Color(0xFF00C7BE),
                          glowColor: const Color(0xFF00C7BE).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated points with sparkle effect
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0, end: _getDailyScore(dayIndex).toDouble()),
                    builder: (context, animatedScore, child) => Row(
                      children: [
                        Text(
                          '${animatedScore.toInt()}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 2),
                          tween: Tween(begin: 0.6, end: 1.0),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            child: Icon(
                              Icons.auto_awesome,
                              color: const Color(0xFFFFD700),
                              size: 24,
                            ),
                          ),
                          onEnd: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'POINTS TODAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress indicators
                  Column(
                    children: [
                      _buildProgressIndicator('Deen', deenProgress, const Color(0xFFFF453A)),
                      const SizedBox(height: 6),
                      _buildProgressIndicator('Personal', personalProgress, const Color(0xFF30D158)),
                      const SizedBox(height: 6),
                      _buildProgressIndicator('Health', healthProgress, const Color(0xFF00C7BE)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStreakCard() {
    int bestDailyScore = _getBestDailyScore();
    int todayScore = _getDailyScore(DateTime.now().weekday == 7 ? 6 : DateTime.now().weekday - 1);
    bool achievedBest = todayScore >= bestDailyScore && todayScore > 0;
    int perfectDays = _getPerfectDaysCount();
    
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D3A),
            const Color(0xFF1E212E).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF9F0A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  achievedBest ? Icons.emoji_events : Icons.workspace_premium,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PERSONAL RECORDS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (achievedBest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'NEW RECORD!',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFD700),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildRecordItem(
                  value: bestDailyScore,
                  label: 'BEST DAILY SCORE',
                  icon: Icons.star,
                  color: const Color(0xFFFFD700),
                  isHighlighted: achievedBest,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildRecordItem(
                  value: perfectDays,
                  label: 'PERFECT DAYS',
                  icon: Icons.grade,
                  color: const Color(0xFF30D158),
                  isHighlighted: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (achievedBest)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.1),
                    const Color(0xFFFF9F0A).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.8, end: 1.2),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: Icon(
                        Icons.celebration,
                        color: const Color(0xFFFFD700),
                        size: 24,
                      ),
                    ),
                    onEnd: () => setState(() {}),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Congratulations!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                        Text(
                          'You achieved your personal best today!',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!achievedBest && bestDailyScore > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: const Color(0xFF007AFF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beat your record!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                        Text(
                          'You need ${bestDailyScore - todayScore + 1} more points',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordItem({
    required int value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted 
          ? color.withValues(alpha: 0.15)
          : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted 
            ? color.withValues(alpha: 0.4)
            : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0, end: value.toDouble()),
                builder: (context, animatedValue, child) => Text(
                  '${animatedValue.toInt()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _getBestDailyScore() {
    int bestScore = 0;
    
    // Check all weeks and days in tracking data
    for (var weekData in _trackingData.values) {
      for (var week in weekData.values) {
        for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
          int dayScore = 0;
          
          for (var category in _categories.entries) {
            for (String habit in category.value) {
              if (!_isHabitDisabled(habit, dayIndex)) {
                HabitState? state = week[dayIndex];
                if (state != null) {
                  int points = _getHabitPoints(habit, state, dayIndex);
                  dayScore += points;
                }
              }
            }
          }
          
          if (dayScore > bestScore) {
            bestScore = dayScore;
          }
        }
      }
    }
    
    return bestScore;
  }

  int _getPerfectDaysCount() {
    int perfectDays = 0;
    
    // Check all weeks and days in tracking data
    for (var weekData in _trackingData.values) {
      for (var week in weekData.values) {
        for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
          int totalHabits = 0;
          int completedHabits = 0;
          
          for (var category in _categories.entries) {
            for (String habit in category.value) {
              if (!_isHabitDisabled(habit, dayIndex)) {
                totalHabits++;
                HabitState? state = week[dayIndex];
                if (state == HabitState.completed || state == HabitState.onTime) {
                  completedHabits++;
                }
              }
            }
          }
          
          if (totalHabits > 0 && completedHabits == totalHabits) {
            perfectDays++;
          }
        }
      }
    }
    
    return perfectDays;
  }

  Widget _buildQuickStatsCard(int dayIndex) {
    int totalCompleted = 0;
    int totalHabits = 0;
    int onTimeHabits = 0;
    int partialHabits = 0;
    
    for (var category in _categories.entries) {
      for (String habit in category.value) {
        if (!_isHabitDisabled(habit, dayIndex)) {
          totalHabits++;
          HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
          if (state == HabitState.completed || state == HabitState.onTime || state == HabitState.partial) {
            totalCompleted++;
            if (state == HabitState.onTime) onTimeHabits++;
            if (state == HabitState.partial) partialHabits++;
          }
        }
      }
    }
    
    double completionRate = totalHabits > 0 ? totalCompleted / totalHabits : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D3A),
            const Color(0xFF1E212E).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TODAY\'S PERFORMANCE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completionRate >= 0.8 
                    ? const Color(0xFF30D158).withValues(alpha: 0.2)
                    : completionRate >= 0.5
                      ? const Color(0xFFFF9F0A).withValues(alpha: 0.2)
                      : const Color(0xFFFF453A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: completionRate >= 0.8 
                      ? const Color(0xFF30D158).withValues(alpha: 0.4)
                      : completionRate >= 0.5
                        ? const Color(0xFFFF9F0A).withValues(alpha: 0.4)
                        : const Color(0xFFFF453A).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  completionRate >= 0.8 ? 'EXCELLENT' 
                    : completionRate >= 0.5 ? 'GOOD' : 'FOCUS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: completionRate >= 0.8 
                      ? const Color(0xFF30D158)
                      : completionRate >= 0.5
                        ? const Color(0xFFFF9F0A)
                        : const Color(0xFFFF453A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Main completion stats
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  value: totalCompleted,
                  label: 'COMPLETED',
                  color: const Color(0xFF30D158),
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  value: totalHabits - totalCompleted,
                  label: 'REMAINING',
                  color: const Color(0xFFFF9F0A),
                  icon: Icons.pending_actions,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Completion rate indicator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1000),
                          tween: Tween(begin: 0, end: completionRate * 100),
                          builder: (context, animatedRate, child) => Text(
                            '${animatedRate.toInt()}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 2),
                          tween: Tween(begin: 0.7, end: 1.0),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            child: Icon(
                              completionRate >= 0.8 ? Icons.celebration : Icons.trending_up,
                              color: completionRate >= 0.8 ? const Color(0xFFFFD700) : const Color(0xFF00C7BE),
                              size: 20,
                            ),
                          ),
                          onEnd: () => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'COMPLETION RATE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Progress bar
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        tween: Tween(begin: 0, end: completionRate),
                        builder: (context, animatedProgress, child) => LinearProgressIndicator(
                          value: animatedProgress,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completionRate >= 0.8 
                              ? const Color(0xFF30D158)
                              : completionRate >= 0.5
                                ? const Color(0xFFFF9F0A)
                                : const Color(0xFFFF453A),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalCompleted of $totalHabits habits',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required int value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0, end: value.toDouble()),
                builder: (context, animatedValue, child) => Text(
                  '${animatedValue.toInt()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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
              color: color.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysFocusSection(int dayIndex) {
    final focusCategories = [
      {'name': 'Deen', 'color': const Color(0xFFFF453A)},
      {'name': 'Personal', 'color': const Color(0xFF30D158)},
      {'name': 'Professional', 'color': const Color(0xFF007AFF)},
      {'name': 'Health', 'color': const Color(0xFF00C7BE)},
      {'name': 'Sleep Tracking', 'color': const Color(0xFF5856D6)},
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: 24), // Add bottom padding for better scrolling
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S FOCUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickStatsCard(dayIndex),
          const SizedBox(height: 24),
          ...focusCategories.map((category) => 
            _buildFocusCategoryCard(
              category['name'] as String,
              category['color'] as Color,
              dayIndex,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildFocusCategoryCard(String categoryName, Color categoryColor, int dayIndex) {
    List<String> categoryHabits = _categories[categoryName] ?? [];
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    
    // Filter habits for weekends
    List<String> availableHabits = categoryHabits.where((habit) {
      return !_isHabitDisabled(habit, dayIndex);
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (availableHabits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isWeekend ? 'Weekend - most habits disabled' : 'No habits in this category',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...availableHabits.map((habit) => _buildTaskItem(habit, dayIndex)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String habitName, int dayIndex) {
    HabitState currentState = _trackingData[habitName]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
    bool isCompleted = currentState == HabitState.completed || 
                      currentState == HabitState.onTime || 
                      currentState == HabitState.partial;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showHabitStateDialog(habitName, dayIndex),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? _getStateColor(currentState) : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? _getStateColor(currentState) : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isCompleted 
                ? _getStateIcon(currentState)
                : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showHabitStateDialog(habitName, dayIndex),
              child: Text(
                habitName,
                style: TextStyle(
                  fontSize: 16,
                  color: isCompleted 
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (currentState != HabitState.none)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStateColor(currentState).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${_getHabitPoints(habitName, currentState, dayIndex)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getStateColor(currentState),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYourProgressSection(int dayIndex, int currentScore) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24), // Add bottom padding for better scrolling
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR PROGRESS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildCompoundHabitsProgressCard(dayIndex),
          const SizedBox(height: 24),
          _buildCategoryProgressSection(dayIndex),
        ],
      ),
    );
  }

  Widget _buildCompoundHabitsProgressCard(int dayIndex) {
    return ValueListenableBuilder<double>(
      valueListenable: _compoundProgressNotifier,
      builder: (context, progress, child) {
        List<String> compoundHabits = _compoundingHabits.toList();
        int completedCount = 0;
        int totalCount = 0;
        
        for (String habit in compoundHabits) {
          if (!_isHabitDisabled(habit, dayIndex)) {
            totalCount++;
            HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
            if (state == HabitState.completed || state == HabitState.onTime || state == HabitState.partial) {
              completedCount++;
            }
          }
        }
        
        // Use the progress from the notifier
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9F0A), // Orange for compound habits
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'COMPOUND HABITS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9F0A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Long-term growth habits that compound over time',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedCount of $totalCount completed',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: AnimatedBuilder(
              animation: _compoundProgressAnimation,
              builder: (context, child) => FractionallySizedBox(
                widthFactor: progress * _compoundProgressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9F0A), Color(0xFFFF6B35)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (totalCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Today: ${_getCompoundHabitsNames(dayIndex, completedCount)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
      },
    );
  }

  String _getCompoundHabitsNames(int dayIndex, int completedCount) {
    List<String> completedHabits = [];
    List<String> compoundHabits = _compoundingHabits.toList();
    
    for (String habit in compoundHabits) {
      if (!_isHabitDisabled(habit, dayIndex)) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state == HabitState.completed || state == HabitState.onTime || state == HabitState.partial) {
          completedHabits.add(habit);
        }
      }
    }
    
    if (completedHabits.isEmpty) {
      return "None completed yet";
    } else if (completedHabits.length <= 3) {
      return completedHabits.join(", ");
    } else {
      return "${completedHabits.take(3).join(", ")} +${completedHabits.length - 3} more";
    }
  }

  Widget _buildProgressScoreCard() {
    return ValueListenableBuilder<int>(
      valueListenable: _pointsNotifier,
      builder: (context, points, child) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$points',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'POINTS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Earned Today',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildAppleFitnessStyleCard(int dayIndex) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D3A),
            const Color(0xFF1E212E).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Enhanced animated icon with pulse effect
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 2),
            tween: Tween(begin: 0.8, end: 1.0),
            curve: Curves.easeInOut,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00C7BE),
                      const Color(0xFF30D158),
                      const Color(0xFF007AFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C7BE).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getHabitIcon(dayIndex),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            onEnd: () => setState(() {}), // Restart animation
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildRealtimeClock(),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF30D158).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF30D158),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getCurrentHabitInAction(dayIndex),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHabitMotivation(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeClock() {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        
        return Text(
          timeString,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 1,
          ),
        );
      },
    );
  }

  IconData _getHabitIcon(int dayIndex) {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    if (currentHour >= 5 && currentHour < 7) {
      return Icons.wb_sunny_outlined;
    } else if (currentHour >= 7 && currentHour < 9) {
      return Icons.fitness_center;
    } else if (currentHour >= 12 && currentHour < 14) {
      return Icons.wb_sunny;
    } else if (currentHour >= 15 && currentHour < 17) {
      return Icons.self_improvement;
    } else if (currentHour >= 17 && currentHour < 19) {
      return Icons.wb_twilight;
    } else if (currentHour >= 19 && currentHour < 21) {
      return Icons.nights_stay;
    } else if (currentHour >= 21 && currentHour < 23) {
      return Icons.local_cafe;
    } else if (currentHour >= 23 || currentHour < 5) {
      return Icons.bedtime;
    } else {
      return Icons.track_changes;
    }
  }

  String _getCurrentHabitInAction(int dayIndex) {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Determine current habit based on time of day
    if (currentHour >= 5 && currentHour < 7) {
      return "Time for Fajr Prayer";
    } else if (currentHour >= 7 && currentHour < 9) {
      return "Morning routine active";
    } else if (currentHour >= 12 && currentHour < 14) {
      return "Time for Duhr Prayer";
    } else if (currentHour >= 15 && currentHour < 17) {
      return "Time for Asr Prayer";
    } else if (currentHour >= 17 && currentHour < 19) {
      return "Time for Maghrib Prayer";
    } else if (currentHour >= 19 && currentHour < 21) {
      return "Time for Isha Prayer";
    } else if (currentHour >= 21 && currentHour < 23) {
      return "Evening activities";
    } else if (currentHour >= 23 || currentHour < 5) {
      return "Sleep time approaching";
    } else {
      return "Keep up the great work!";
    }
  }

  String _getHabitMotivation() {
    final motivations = [
      "Stay consistent, stay strong",
      "Every habit counts",
      "Building a better you",
      "Progress over perfection",
      "Small steps, big changes",
      "You're doing amazing",
    ];
    final now = DateTime.now();
    return motivations[now.hour % motivations.length];
  }

  Widget _buildCategoryProgressSection(int dayIndex) {
    final progressCategories = [
      {'name': 'Deen', 'color': const Color(0xFFFF453A)},
      {'name': 'Personal', 'color': const Color(0xFF30D158)},
      {'name': 'Professional', 'color': const Color(0xFF007AFF)},
      {'name': 'Health', 'color': const Color(0xFF00C7BE)},
      {'name': 'Sleep Tracking', 'color': const Color(0xFF5856D6)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY PROGRESS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...progressCategories.map((category) => 
            _buildCategoryProgressItem(
              category['name'] as String,
              category['color'] as Color,
              dayIndex,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgressItem(String categoryName, Color categoryColor, int dayIndex) {
    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: _categoryProgressNotifier,
      builder: (context, categoryProgressMap, child) {
        double progress = categoryProgressMap[categoryName] ?? _getCategoryProgress(categoryName, dayIndex);
        int completed = _getCategoryCompletedCount(categoryName, dayIndex);
        int total = _getCategoryTotalCount(categoryName, dayIndex);
        
        return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                '$completed/$total tasks (${(progress * 100).toInt()}%)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: AnimatedBuilder(
              animation: _categoryProgressAnimation,
              builder: (context, child) => FractionallySizedBox(
                widthFactor: progress * _categoryProgressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: categoryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  int _getCategoryCompletedCount(String categoryName, int dayIndex) {
    List<String> habits = _categories[categoryName] ?? [];
    int completed = 0;
    
    for (String habit in habits) {
      if (!_isHabitDisabled(habit, dayIndex)) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state == HabitState.completed || state == HabitState.onTime || state == HabitState.partial) {
          completed++;
        }
      }
    }
    return completed;
  }

  int _getCategoryTotalCount(String categoryName, int dayIndex) {
    List<String> habits = _categories[categoryName] ?? [];
    int total = 0;
    
    for (String habit in habits) {
      if (!_isHabitDisabled(habit, dayIndex)) {
        total++;
      }
    }
    return total;
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
    bool isDisabled = _isHabitDisabled(habit, dayIndex);
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
                bool isDisabled = _isHabitDisabled(habit, dayIndex);
                
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
              bool isDisabled = _isHabitDisabled(habit, dayIndex);
              
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

  // Individual Category Rings Widget
  Widget _buildIndividualCategoryRings(int dayIndex) {
    final categories = [
      {'name': 'Deen', 'color': const Color(0xFFFF453A), 'title': 'Deen'},
      {'name': 'Personal', 'color': const Color(0xFF30D158), 'title': 'Personal'},
      {'name': 'Professional', 'color': const Color(0xFFFF9F0A), 'title': 'Professional'},
      {'name': 'Health', 'color': const Color(0xFF00C7BE), 'title': 'Health'},
      {'name': 'Sleep', 'color': const Color(0xFF007AFF), 'title': 'Sleep'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> category = entry.value;
                double progress = _getCategoryProgress(category['name'] as String, dayIndex);
                Color color = category['color'] as Color;
                String title = category['title'] as String;
                
                return Container(
                  width: 100,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 8,
                    right: index == categories.length - 1 ? 0 : 8,
                  ),
                  child: _buildIndividualRing(
                    progress: progress,
                    color: color,
                    title: title,
                    categoryName: category['name'] as String,
                    dayIndex: dayIndex,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualRing({
    required double progress,
    required Color color,
    required String title,
    required String categoryName,
    required int dayIndex,
  }) {
    int currentScore = _getCategoryScore(categoryName, dayIndex);
    int maxScore = _getCategoryMaxScore(categoryName, dayIndex);
    
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ringAnimation,
                builder: (context, child) => CustomPaint(
                  size: const Size(80, 80),
                  painter: ActivityRingPainter(
                    progress: progress * _ringAnimation.value,
                    color: color,
                    strokeWidth: 8,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$currentScore/$maxScore',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  int _getCategoryScore(String categoryName, int dayIndex) {
    List<String> habits = _categories[categoryName] ?? [];
    
    int currentScore = 0;
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    
    for (String habit in habits) {
      bool isDisabled = _isHabitDisabled(habit, dayIndex);
      
      if (!isDisabled) {
        HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
        if (state != HabitState.none) {
          currentScore += _habitStatePoints[habit]?[state] ?? 0;
        }
      }
    }
    return currentScore;
  }

  int _getCategoryMaxScore(String categoryName, int dayIndex) {
    List<String> habits = _categories[categoryName] ?? [];
    
    int maxScore = 0;
    bool isWeekend = dayIndex == 5 || dayIndex == 6;
    
    for (String habit in habits) {
      bool isDisabled = _isHabitDisabled(habit, dayIndex);
      
      if (!isDisabled) {
        maxScore += _getMaxHabitPoints(habit);
      }
    }
    return maxScore;
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
                    progress: _getCategoryProgress('Deen', dayIndex) * _ringAnimation.value,
                    color: const Color(0xFFFF453A), // Red ring
                  ),
                ),
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) => _buildActivityRing(
                    radius: 65,
                    strokeWidth: 12,
                    progress: _getCategoryProgress('Personal', dayIndex) * _ringAnimation.value,
                    color: const Color(0xFF30D158), // Green ring
                  ),
                ),
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) => _buildActivityRing(
                    radius: 45,
                    strokeWidth: 12,
                    progress: _getCategoryProgress('Health', dayIndex) * _ringAnimation.value,
                    color: const Color(0xFF00C7BE), // Cyan ring
                  ),
                ),
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) => _buildActivityRing(
                    radius: 25,
                    strokeWidth: 12,
                    progress: _getCategoryProgress('Sleep Tracking', dayIndex) * _ringAnimation.value,
                    color: const Color(0xFF5856D6), // Purple ring
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

  Widget _buildEnhancedActivityRing({
    required double radius,
    required double strokeWidth,
    required double progress,
    required Color color,
    required Color glowColor,
  }) {
    return CustomPaint(
      size: Size(radius * 2, radius * 2),
      painter: EnhancedActivityRingPainter(
        progress: progress,
        color: color,
        glowColor: glowColor,
        strokeWidth: strokeWidth,
      ),
    );
  }

  Widget _buildProgressIndicator(String label, double progress, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildRingLegend() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) {
            DateTime now = DateTime.now();
            int currentDayIndex = now.weekday == 7 ? 6 : now.weekday - 1; // Convert to 0-6 system
            return _buildLegendItem(
              color: const Color(0xFFFF453A),
              title: 'Deen',
              subtitle: '${(_getCategoryProgress('Deen', currentDayIndex) * _ringAnimation.value * 100).toInt()}% complete',
            );
          },
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) {
            DateTime now = DateTime.now();
            int currentDayIndex = now.weekday == 7 ? 6 : now.weekday - 1; // Convert to 0-6 system
            return _buildLegendItem(
              color: const Color(0xFF30D158),
              title: 'Personal',
              subtitle: '${(_getCategoryProgress('Personal', currentDayIndex) * _ringAnimation.value * 100).toInt()}% complete',
            );
          },
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) {
            DateTime now = DateTime.now();
            int currentDayIndex = now.weekday == 7 ? 6 : now.weekday - 1; // Convert to 0-6 system
            return _buildLegendItem(
              color: const Color(0xFF00C7BE),
              title: 'Health',
              subtitle: '${(_getCategoryProgress('Health', currentDayIndex) * _ringAnimation.value * 100).toInt()}% complete',
            );
          },
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) {
            DateTime now = DateTime.now();
            int currentDayIndex = now.weekday == 7 ? 6 : now.weekday - 1; // Convert to 0-6 system
            return _buildLegendItem(
              color: const Color(0xFF5856D6),
              title: 'Sleep Tracking',
              subtitle: '${(_getCategoryProgress('Sleep Tracking', currentDayIndex) * _ringAnimation.value * 100).toInt()}% complete',
            );
          },
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
    bool isDisabled = _isHabitDisabled(habit, dayIndex);
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
  // Compounding Habits Chart Widget
  Widget _buildCompoundingHabitsChart(int dayIndex) {
    List<String> compoundingHabitsList = _compoundingHabits.toList();
    int completedCount = 0;
    int totalCount = 0;
    
    Map<String, double> categoryProgress = {};
    Map<String, Color> categoryColors = {
      'Deen': const Color(0xFFFF453A),
      'Personal': const Color(0xFF30D158),
      'Professional': const Color(0xFFFF9F0A),
      'Health': const Color(0xFF00C7BE),
    };
    
    // Calculate progress for each category
    for (String category in ['Deen', 'Personal', 'Professional', 'Health']) {
      List<String> categoryHabits = _categories[category] ?? [];
      List<String> compoundingInCategory = categoryHabits.where((habit) => _compoundingHabits.contains(habit)).toList();
      
      if (compoundingInCategory.isNotEmpty) {
        int categoryCompleted = 0;
        int categoryTotal = compoundingInCategory.length;
        
        bool isWeekend = dayIndex == 5 || dayIndex == 6;
        
        for (String habit in compoundingInCategory) {
          bool isDisabled = _isHabitDisabled(habit, dayIndex);
          
          if (!isDisabled) {
            totalCount++;
            HabitState state = _trackingData[habit]?[_currentWeekKey]?[dayIndex] ?? HabitState.none;
            if (state == HabitState.completed || state == HabitState.onTime || state == HabitState.partial) {
              completedCount++;
              categoryCompleted++;
            }
          }
        }
        
        categoryProgress[category] = categoryTotal > 0 ? categoryCompleted / categoryTotal : 0.0;
      }
    }
    
    double overallProgress = totalCount > 0 ? completedCount / totalCount : 0.0;
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compounding Habits',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${(overallProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9F0A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Long-term growth habits that compound over time',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          
          // Overall progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) => FractionallySizedBox(
                widthFactor: overallProgress * _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9F0A), Color(0xFFFF453A)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            '$completedCount of $totalCount habits completed',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // Category breakdown
          ...categoryProgress.entries.map((entry) {
            String category = entry.key;
            double progress = entry.value;
            Color color = categoryColors[category] ?? Colors.grey;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
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
                    flex: 2,
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) => FractionallySizedBox(
                          widthFactor: progress * _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
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

class EnhancedActivityRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color glowColor;
  final double strokeWidth;

  EnhancedActivityRingPainter({
    required this.progress,
    required this.color,
    required this.glowColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Background ring with subtle glow
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Glow effect for progress ring
    final glowPaint = Paint()
      ..color = glowColor
      ..strokeWidth = strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);

    const startAngle = -math.pi / 2; // Start at top
    final sweepAngle = 2 * math.pi * progress;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );
    }

    // Progress ring with gradient effect
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color,
          color.withValues(alpha: 0.8),
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Habit {
  final String id;
  final String title;
  final String category;
  final String icon;
  final String description;
  final String createdAt;
  final String updatedAt;

  Habit({
    required this.id,
    required this.title,
    required this.category,
    this.icon = '',
    this.description = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      icon: json['icon'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'icon': icon,
      'description': description,
    };
  }

  Habit copyWith({
    String? id,
    String? title,
    String? category,
    String? icon,
    String? description,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class UserHabitPoints {
  final String userId;
  final String habitId;
  final int points;

  UserHabitPoints({
    required this.userId,
    required this.habitId,
    required this.points,
  });

  factory UserHabitPoints.fromJson(Map<String, dynamic> json) {
    return UserHabitPoints(
      userId: json['userId'] ?? '',
      habitId: json['habitId'] ?? '',
      points: json['points'] ?? 0,
    );
  }
}

enum CompletionStatus {
  none,
  onTime,
  delayed,
  partial,
  completed,
  missed,
  avoided
}

class Event {
  final String id;
  final Habit habit;
  final int startMinutes;
  final int durationMinutes;
  final int points;
  final CompletionStatus completionStatus;
  final String? notes;

  Event({
    required this.id,
    required this.habit,
    required this.startMinutes,
    required this.durationMinutes,
    required this.points,
    this.completionStatus = CompletionStatus.none,
    this.notes,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      habit: json['habit'] != null 
          ? Habit.fromJson(json['habit']) 
          : Habit(id: json['habitId'] ?? '', title: json['habitName'] ?? '', category: ''),
      startMinutes: json['startMinutes'] ?? 0,
      durationMinutes: json['durationMinutes'] ?? 0,
      points: json['points'] ?? 0,
      completionStatus: _parseCompletionStatus(json['completionStatus']),
      notes: json['notes'],
    );
  }

  static CompletionStatus _parseCompletionStatus(String? status) {
    switch (status) {
      case 'onTime':
        return CompletionStatus.onTime;
      case 'delayed':
        return CompletionStatus.delayed;
      case 'partial':
        return CompletionStatus.partial;
      case 'completed':
        return CompletionStatus.completed;
      case 'missed':
        return CompletionStatus.missed;
      case 'avoided':
        return CompletionStatus.avoided;
      default:
        return CompletionStatus.none;
    }
  }

  static String _completionStatusToString(CompletionStatus status) {
    switch (status) {
      case CompletionStatus.onTime:
        return 'onTime';
      case CompletionStatus.delayed:
        return 'delayed';
      case CompletionStatus.partial:
        return 'partial';
      case CompletionStatus.completed:
        return 'completed';
      case CompletionStatus.missed:
        return 'missed';
      case CompletionStatus.avoided:
        return 'avoided';
      case CompletionStatus.none:
      default:
        return 'none';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habit.id,
      'habit': habit.toJson(),
      'startMinutes': startMinutes,
      'durationMinutes': durationMinutes,
      'points': points,
      'completionStatus': _completionStatusToString(completionStatus),
      'notes': notes,
    };
  }

  Event copyWith({
    String? id,
    Habit? habit,
    int? startMinutes,
    int? durationMinutes,
    int? points,
    CompletionStatus? completionStatus,
    String? notes,
  }) {
    return Event(
      id: id ?? this.id,
      habit: habit ?? this.habit,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      points: points ?? this.points,
      completionStatus: completionStatus ?? this.completionStatus,
      notes: notes ?? this.notes,
    );
  }

  int get startHour => startMinutes ~/ 60;
  int get startMinute => startMinutes % 60;
  int get endMinutes => startMinutes + durationMinutes;
  int get endHour => endMinutes ~/ 60;
  int get endMinute => endMinutes % 60;
  
  String get startTimeFormatted {
    final hour12 = startHour == 0 ? 12 : (startHour > 12 ? startHour - 12 : startHour);
    final period = startHour < 12 ? 'AM' : 'PM';
    return '$hour12:${startMinute.toString().padLeft(2, '0')} $period';
  }
  String get endTimeFormatted {
    final hour12 = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour);
    final period = endHour < 12 ? 'AM' : 'PM';
    return '$hour12:${endMinute.toString().padLeft(2, '0')} $period';
  }
  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  // Convenience getters to maintain backward compatibility
  String get habitId => habit.id;
  String get habitName => habit.title;
}

// Deprecated: Use Event instead. Kept for backward compatibility during migration.
@Deprecated('Use Event instead')
typedef TimelineEntry = Event;

class Timeline {
  final String id;
  final String userId;
  final String date;
  final List<Event> entries;

  Timeline({
    required this.id,
    required this.userId,
    required this.date,
    required this.entries,
  });

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      date: json['date'] ?? '',
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => Event.fromJson(e))
              .toList() ??
          [],
    );
  }

  int get totalPoints => entries.fold(0, (sum, e) => sum + e.points);
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
    };
  }
}

class Panel {
  final String id;
  final String name;
  final String type;
  final int order;
  final bool isVisible;
  final Map<String, dynamic> config;

  Panel({
    required this.id,
    required this.name,
    required this.type,
    this.order = 0,
    this.isVisible = true,
    this.config = const {},
  });

  factory Panel.fromJson(Map<String, dynamic> json) {
    return Panel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      order: json['order'] ?? 0,
      isVisible: json['isVisible'] ?? true,
      config: json['config'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'order': order,
      'isVisible': isVisible,
      'config': config,
    };
  }

  Panel copyWith({
    String? id,
    String? name,
    String? type,
    int? order,
    bool? isVisible,
    Map<String, dynamic>? config,
  }) {
    return Panel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      order: order ?? this.order,
      isVisible: isVisible ?? this.isVisible,
      config: config ?? this.config,
    );
  }
}

class TimelineConfig {
  final String id;
  final String name;
  final int startHour;
  final int endHour;
  final int maxPoints;
  final List<String> panelIds;

  TimelineConfig({
    required this.id,
    required this.name,
    this.startHour = 0,
    this.endHour = 24,
    this.maxPoints = 100,
    this.panelIds = const [],
  });

  factory TimelineConfig.fromJson(Map<String, dynamic> json) {
    return TimelineConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      startHour: json['startHour'] ?? 0,
      endHour: json['endHour'] ?? 24,
      maxPoints: json['maxPoints'] ?? 100,
      panelIds: List<String>.from(json['panelIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startHour': startHour,
      'endHour': endHour,
      'maxPoints': maxPoints,
      'panelIds': panelIds,
    };
  }

  TimelineConfig copyWith({
    String? id,
    String? name,
    int? startHour,
    int? endHour,
    int? maxPoints,
    List<String>? panelIds,
  }) {
    return TimelineConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      maxPoints: maxPoints ?? this.maxPoints,
      panelIds: panelIds ?? this.panelIds,
    );
  }
}

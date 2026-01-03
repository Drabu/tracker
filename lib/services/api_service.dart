import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String _baseUrl = 'http://localhost:8080/api';

  static Future<List<Habit>> getHabits() async {
    final response = await http.get(Uri.parse('$_baseUrl/habits'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Habit.fromJson(e)).toList();
    }
    throw Exception('Failed to load habits');
  }

  static Future<List<String>> getCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/habits/categories'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => e.toString()).toList();
    }
    throw Exception('Failed to load categories');
  }

  static Future<Habit> createHabit({
    required String title,
    required String category,
    String icon = '',
    String description = '',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/habits'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'category': category,
        'icon': icon,
        'description': description,
      }),
    );
    if (response.statusCode == 201) {
      return Habit.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create habit');
  }

  static Future<Habit> updateHabit(String id, Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/habits/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );
    if (response.statusCode == 200) {
      return Habit.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update habit');
  }

  static Future<void> deleteHabit(String id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/habits/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete habit');
    }
  }

  static Future<AppUser> createOrGetUser(String name, String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return AppUser.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create/get user');
  }

  static Future<List<UserHabitPoints>> getUserHabitPoints(String userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/$userId/habit-points'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => UserHabitPoints.fromJson(e)).toList();
    }
    throw Exception('Failed to load user habit points');
  }

  static Future<void> setUserHabitPoints(String userId, String habitId, int points) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/habit-points'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'habitId': habitId, 'points': points}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set habit points');
    }
  }

  static Future<Timeline?> getTimelineByDate(String userId, String date) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/timelines?userId=$userId&date=$date'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null) return null;
      return Timeline.fromJson(data);
    }
    throw Exception('Failed to load timeline');
  }

  static Future<List<Timeline>> getUserTimelines(String userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/timelines?userId=$userId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Timeline.fromJson(e)).toList();
    }
    throw Exception('Failed to load timelines');
  }

  static Future<Timeline> saveTimeline({
    required String userId,
    required String date,
    required List<TimelineEntry> entries,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/timelines'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'date': date,
        'entries': entries.map((e) => e.toJson()).toList(),
      }),
    );
    if (response.statusCode == 200) {
      return Timeline.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to save timeline');
  }

  static Future<Map<String, dynamic>> validateTimeline(List<TimelineEntry> entries) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/timelines/validate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'entries': entries.map((e) => e.toJson()).toList(),
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to validate timeline');
  }

  static Future<Timeline> updateEntryStatus({
    required String timelineId,
    required String entryId,
    required String status,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/timelines/$timelineId/entry-status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'entryId': entryId,
        'status': status,
      }),
    );
    if (response.statusCode == 200) {
      return Timeline.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update entry status');
  }

  static Future<List<String>> getUserCompoundHabits(String userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/$userId/compound-habits'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => e.toString()).toList();
    }
    throw Exception('Failed to load compound habits');
  }

  static Future<void> setUserCompoundHabit(String userId, String habitId, bool isCompound) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/compound-habits'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'habitId': habitId, 'isCompound': isCompound}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set compound habit');
    }
  }
}

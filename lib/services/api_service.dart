import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String _prodUrl = 'https://api.rythmn.online/api';
  static const String _devUrl = 'http://localhost:8080/api';
  static String get _baseUrl => kReleaseMode ? _prodUrl : _devUrl;

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
    required List<Event> entries,
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

  static Future<Map<String, dynamic>> validateTimeline(List<Event> entries) async {
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

  static Future<Timeline> clearTimelineEntries({
    required String userId,
    required String date,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/timelines/clear/entries?userId=$userId&date=$date'),
    );
    if (response.statusCode == 200) {
      return Timeline.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to clear timeline entries');
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

  static Future<List<Contest>> getContests() async {
    final response = await http.get(Uri.parse('$_baseUrl/contests'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Contest.fromJson(e)).toList();
    }
    throw Exception('Failed to load contests');
  }

  static Future<Contest> getContest(String id) async {
    final response = await http.get(Uri.parse('$_baseUrl/contests/$id'));
    if (response.statusCode == 200) {
      return Contest.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load contest');
  }

  static Future<Contest> createContest({
    required String name,
    required String description,
    required String creatorId,
    required String startDate,
    required String endDate,
    required List<String> userIds,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/contests'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'startDate': startDate,
        'endDate': endDate,
        'userIds': userIds,
      }),
    );
    if (response.statusCode == 201) {
      return Contest.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create contest');
  }

  static Future<void> deleteContest(String id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/contests/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete contest');
    }
  }

  static Future<List<UserBasic>> getAllUsers() async {
    final response = await http.get(Uri.parse('$_baseUrl/users-list'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => UserBasic.fromJson(e)).toList();
    }
    throw Exception('Failed to load users');
  }

  static Future<Map<String, dynamic>> getAlexaSettings(String userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/$userId/alexa-settings'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load Alexa settings');
  }

  static Future<void> setAlexaSettings(String userId, String alexaAccessCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/alexa-settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'alexaAccessCode': alexaAccessCode}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save Alexa settings');
    }
  }

  // Generate Alexa link code for skill linking
  static Future<String> generateAlexaLinkCode(String userId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/alexa/link'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['code'];
    }
    throw Exception('Failed to generate link code');
  }

  // Get Alexa Reminder settings (LWA OAuth)
  static Future<Map<String, dynamic>> getAlexaReminderSettings(String userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/$userId/alexa-reminder-settings'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load Alexa Reminder settings');
  }

  // Save Alexa Reminder settings (after OAuth)
  static Future<void> setAlexaReminderSettings(
    String userId,
    String accessToken,
    String refreshToken,
    String apiEndpoint,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/alexa-reminder-settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'apiEndpoint': apiEndpoint,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save Alexa Reminder settings');
    }
  }

  // Exchange Alexa OAuth code for tokens
  static Future<void> exchangeAlexaReminderToken(
    String userId,
    String code,
    String redirectUri,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/alexa-reminder-token-exchange'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'redirectUri': redirectUri,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to exchange Alexa token: ${response.body}');
    }
  }

  // Delete Alexa Reminder settings (disconnect)
  static Future<void> deleteAlexaReminderSettings(String userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/$userId/alexa-reminder-settings'),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to disconnect Alexa Reminders');
    }
  }
}

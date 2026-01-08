import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AuthService {
  static const String _prodUrl = 'https://api.rythmn.online/api';
  static const String _devUrl = 'http://localhost:8080/api';
  static String get _baseUrl => kReleaseMode ? _prodUrl : _devUrl;

  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb
        ? '146630121520-8ednqm0gqmr0ngnfvaa3crhvmjijruni.apps.googleusercontent.com'
        : null,
  );

  static AppUser? _currentUser;
  static String? _authToken;

  static AppUser? get currentUser => _currentUser;
  static String? get authToken => _authToken;
  static bool get isLoggedIn => _currentUser != null;

  static Future<AppUser?> getCurrentUser() async {
    if (_currentUser == null) {
      await init();
    }
    return _currentUser;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    _authToken = prefs.getString(_tokenKey);

    if (userJson != null) {
      _currentUser = AppUser.fromJson(jsonDecode(userJson));
    }
  }

  static Future<AppUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': googleAuth.idToken,
          'accessToken': googleAuth.accessToken,
          'email': googleUser.email,
          'name': googleUser.displayName ?? googleUser.email.split('@')[0],
          'photoUrl': googleUser.photoUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentUser = AppUser.fromJson(data['user']);
        _authToken = data['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
        if (_authToken != null) {
          await prefs.setString(_tokenKey, _authToken!);
        }

        return _currentUser;
      }

      throw Exception('Failed to authenticate with server');
    } catch (e) {
      print('Google Sign-In error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Google Sign-Out error: $e');
    }

    _currentUser = null;
    _authToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }

  static Future<bool> isSignedIn() async {
    await init();
    return _currentUser != null;
  }

  static Map<String, String> get authHeaders {
    if (_authToken != null) {
      return {'Authorization': 'Bearer $_authToken'};
    }
    return {};
  }
}

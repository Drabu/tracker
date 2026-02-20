import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service to handle Alexa OAuth callback
class AlexaOAuthService {
  static final AlexaOAuthService _instance = AlexaOAuthService._internal();
  factory AlexaOAuthService() => _instance;
  AlexaOAuthService._internal();

  /// Stream controller for OAuth completion events
  final _oauthCompleteController = StreamController<bool>.broadcast();
  
  /// Stream that emits true when OAuth is successful, false on failure
  Stream<bool> get onOAuthComplete => _oauthCompleteController.stream;

  /// Pending user ID for the OAuth flow
  String? _pendingUserId;

  /// Set the user ID before starting OAuth flow
  void setPendingUserId(String userId) {
    _pendingUserId = userId;
  }

  /// Handle the OAuth callback URL
  /// Returns true if the URL was an OAuth callback and was handled
  Future<bool> handleCallbackUrl(Uri uri) async {
    // Check if this is our Alexa callback
    if (uri.scheme != 'rythmn' || uri.host != 'alexa-callback') {
      return false;
    }

    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      debugPrint('Alexa OAuth error: $error');
      _oauthCompleteController.add(false);
      return true;
    }

    if (code == null || code.isEmpty) {
      debugPrint('Alexa OAuth: No code received');
      _oauthCompleteController.add(false);
      return true;
    }

    if (_pendingUserId == null) {
      debugPrint('Alexa OAuth: No pending user ID');
      _oauthCompleteController.add(false);
      return true;
    }

    try {
      // Exchange the code for tokens via backend
      await ApiService.exchangeAlexaReminderToken(
        _pendingUserId!,
        code,
        'rythmn://alexa-callback',
      );
      
      debugPrint('Alexa OAuth successful');
      _oauthCompleteController.add(true);
      _pendingUserId = null;
      return true;
    } catch (e) {
      debugPrint('Alexa OAuth token exchange failed: $e');
      _oauthCompleteController.add(false);
      return true;
    }
  }

  /// Handle web URL (for web platform)
  Future<bool> handleWebUrl() async {
    if (!kIsWeb) return false;
    
    // On web, check the current URL for OAuth callback parameters
    // This would be called on app init
    try {
      // Web URL handling would go here
      // For web, you'd typically use a redirect URI that's a page on your domain
      return false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _oauthCompleteController.close();
  }
}

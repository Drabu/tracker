import 'dart:async';
import 'package:flutter/foundation.dart';
import 'alexa_oauth_service.dart';

// Conditional import for uni_links (mobile only)
import 'deep_link_handler_stub.dart'
    if (dart.library.io) 'deep_link_handler_mobile.dart' as platform;

/// Cross-platform deep link handler
class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  StreamSubscription? _subscription;
  bool _initialized = false;

  /// Initialize deep link handling
  /// Call this once in main.dart after runApp
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      // Web doesn't use deep links the same way
      // OAuth callback would be handled via redirect to a web page
      debugPrint('DeepLinkHandler: Web platform - deep links handled differently');
      return;
    }

    // Mobile platform handling
    await platform.initDeepLinks(
      onLink: _handleDeepLink,
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('DeepLinkHandler: Received deep link: $uri');
    
    // Try to handle as Alexa OAuth callback
    final handled = await AlexaOAuthService().handleCallbackUrl(uri);
    
    if (!handled) {
      debugPrint('DeepLinkHandler: Unhandled deep link: $uri');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

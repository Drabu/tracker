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

  /// Notifier for pending contest invite (contestId)
  static final ValueNotifier<String?> pendingInvite = ValueNotifier<String?>(null);

  /// Initialize deep link handling
  /// Call this once in main.dart after runApp
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      // On web, check the current browser URL for invite links
      final uri = Uri.base;
      debugPrint('DeepLinkHandler: Web URL: $uri');
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'invite') {
        final contestId = uri.pathSegments[1];
        debugPrint('DeepLinkHandler: Web invite detected: $contestId');
        pendingInvite.value = contestId;
      }
      return;
    }

    // Mobile platform handling
    await platform.initDeepLinks(
      onLink: _handleDeepLink,
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('DeepLinkHandler: Received deep link: $uri');

    // Check for contest invite link: https://app.rythmn.fit/invite/{contestId}
    if (uri.host == 'app.rythmn.fit' && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'invite') {
      final contestId = uri.pathSegments[1];
      debugPrint('DeepLinkHandler: Contest invite detected: $contestId');
      pendingInvite.value = contestId;
      return;
    }

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

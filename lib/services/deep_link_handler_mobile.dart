import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uni_links/uni_links.dart';

/// Mobile implementation using uni_links
Future<void> initDeepLinks({required Function(Uri) onLink}) async {
  // Handle initial link (app opened via deep link)
  try {
    final initialUri = await getInitialUri();
    if (initialUri != null) {
      debugPrint('DeepLinkHandler: Initial URI: $initialUri');
      onLink(initialUri);
    }
  } catch (e) {
    debugPrint('DeepLinkHandler: Failed to get initial URI: $e');
  }

  // Handle incoming links while app is running
  uriLinkStream.listen(
    (Uri? uri) {
      if (uri != null) {
        debugPrint('DeepLinkHandler: Incoming URI: $uri');
        onLink(uri);
      }
    },
    onError: (err) {
      debugPrint('DeepLinkHandler: URI stream error: $err');
    },
  );
}

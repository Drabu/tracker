import 'dart:async';

bool get isWeb => false;

void evalJs(String code) {}

void setLocalStorageItem(String key, String value) {}

Object? createAudioElement() => null;

void audioSetPreload(Object? el, String preload) {}

void audioSetSrc(Object? el, String src) {}

Stream<Object?> audioOnError(Object? el) => const Stream.empty();

int audioReadyState(Object? el) => 0;

void audioReset(Object? el) {}

Future<void> audioPlay(Object? el) async {}

Object? createAudioContext() => null;

String? audioContextState(Object? ctx) => null;

Future<void> audioContextResume(Object? ctx) async {}

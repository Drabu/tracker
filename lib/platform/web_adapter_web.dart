import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

bool get isWeb => true;

void evalJs(String code) {
  js.context.callMethod('eval', [code]);
}

void setLocalStorageItem(String key, String value) {
  html.window.localStorage[key] = value;
}

Object createAudioElement() => html.AudioElement();

void audioSetPreload(Object? el, String preload) {
  (el as html.AudioElement).preload = preload;
}

void audioSetSrc(Object? el, String src) {
  (el as html.AudioElement).src = src;
}

Stream<Object?> audioOnError(Object? el) {
  return (el as html.AudioElement).onError;
}

int audioReadyState(Object? el) {
  return (el as html.AudioElement).readyState;
}

void audioReset(Object? el) {
  (el as html.AudioElement).currentTime = 0;
}

Future<void> audioPlay(Object? el) async {
  await (el as html.AudioElement).play();
}

Object? createAudioContext() {
  final ctor = js.context['AudioContext'];
  if (ctor == null) return null;
  return js.JsObject(ctor);
}

String? audioContextState(Object? ctx) {
  return (ctx as js.JsObject)['state'] as String?;
}

Future<void> audioContextResume(Object? ctx) async {
  await (ctx as js.JsObject).callMethod('resume');
}

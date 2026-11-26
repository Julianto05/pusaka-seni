import 'dart:io' show Platform;

bool isFlutterTestEnvironment() {
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

bool isWindowsDesktop() {
  try {
    return Platform.isWindows;
  } catch (_) {
    return false;
  }
}

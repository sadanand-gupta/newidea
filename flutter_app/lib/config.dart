import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override with: flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // The Android emulator reaches the host machine through 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    // Use localhost for web/desktop, or your machine's IP for physical devices
    return 'http://localhost:8080';
  }
}

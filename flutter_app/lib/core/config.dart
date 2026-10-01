import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  /// App version shown in the drawer footer and About dialog.
  static const version = '1.0.0';

  /// ──────────────────────────────────────────────────────────────────────────
  /// Set this to your Render.com URL after deploying the backend.
  /// Example: 'https://kryptox-backend.onrender.com'
  /// Leave empty to keep using localhost during development.
  /// ──────────────────────────────────────────────────────────────────────────
  static const _renderUrl = String.fromEnvironment(
    'RENDER_URL',
    defaultValue: 'https://kryptox-app.onrender.com',
  );

  /// Override with: flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    // 1. Explicit override always wins
    if (_override.isNotEmpty) return _override;

    // 2. Render URL (for physical devices / production builds)
    if (_renderUrl.isNotEmpty) return _renderUrl;

    // 3. Android emulator reaches the host machine through 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }

    // 4. Localhost fallback for web/desktop dev
    return 'http://localhost:8080';
  }
}


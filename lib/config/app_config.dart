import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration
  static String get apiBaseUrl {
    // If we're in development mode (e.g., flutter run), use localhost
    if (kDebugMode) {
      if (kIsWeb) {
        return 'http://localhost:5004/';
      }
      try {
        if (Platform.isAndroid) {
          // 10.0.2.2 is the special alias to your host loopback interface in Android emulator
          return 'http://localhost:5004/';
        }
      } catch (e) {}
      return 'http://localhost:5004/';
    }

    // Production URL
    return 'http://localhost:5004/';
  }

  static const String apiVersion = 'v1';

  // Feature Flags
  static const bool enableSync = true;
  static const bool enableOfflineMode = true;
  static const bool enableBackup = true;

  // Environment
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
}

/// OSINT API Configuration
///
/// Configure your API keys here to enable full intelligence lookups.
///
/// --- Django osint_backend (local server) ---
/// Runs on your machine at http://127.0.0.1:8000 (desktop/web)
/// or http://10.0.2.2:8000 (Android emulator → host machine loopback).
/// Start with: .\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
///
/// --- HaveIBeenPwned (email breach accounts) ---
/// API key is now stored on the backend server in .env — NOT in the app.
///
/// --- NumVerify (phone carrier & location) ---
/// Get a FREE key (250 calls/month) at: https://apilayer.com/marketplace/number_verification-api
///
library;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class OsintConfig {
  // ---- Django osint_backend URL ----
  /// Returns the correct base URL for the local Django REST API at runtime.
  ///
  /// - Android emulator: host machine's localhost is exposed as 10.0.2.2
  /// - iOS simulator, Windows, macOS, Linux desktop, Flutter web: use 127.0.0.1
  ///
  /// For a physical device on LAN, override this with your PC's LAN IP:
  /// ⚠️  PHYSICAL DEVICE ONLY: set this to your PC's LAN IP.
  ///
  /// Run `ipconfig` in PowerShell and look for "IPv4 Address" under Wi-Fi.
  /// Example: 'http://192.168.1.105:8000'
  ///
  /// Leave empty to auto-detect (emulator uses 10.0.2.2, desktop uses 127.0.0.1).
  static const String _localIp = 'http://192.168.1.3:8000';

  static String get backendBaseUrl {
    return _localIp;
  }

  // ---- Fallback: direct HIBP keys (used only if backend is unreachable) ----

  /// HaveIBeenPwned API key — leave empty to rely entirely on the backend.
  static const String hibpApiKey = '';

  /// NumVerify API key for phone carrier/location lookup.
  static const String numVerifyApiKey = '';

  // ---- External endpoints (do not change) ----
  static const String hibpBreachedAccountUrl =
      'https://haveibeenpwned.com/api/v3/breachedaccount';
  static const String hibpPwnedPasswordsUrl =
      'https://api.pwnedpasswords.com/range';
  static const String numVerifyUrl =
      'https://api.apilayer.com/number_verification/validate';
}

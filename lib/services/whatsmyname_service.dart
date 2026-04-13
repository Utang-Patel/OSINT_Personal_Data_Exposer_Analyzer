// lib/services/whatsmyname_service.dart
//
// WhatsMyName integration — delegates to the Django backend.
// The backend reads the local wmn-data.json and checks 500+ sites
// server-side (no CORS issues, proper redirect control, real User-Agents).
//
// Endpoint: GET /api/v1/osint/wmn/?username=<username>

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'osint_config.dart';

/// A single result from a WhatsMyName site check.
class WmnResult {
  final String name;
  final String url;
  final String category;
  final bool found;

  const WmnResult({
    required this.name,
    required this.url,
    required this.category,
    required this.found,
  });

  factory WmnResult.fromJson(Map<String, dynamic> json) => WmnResult(
        name: json['name']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        category: json['category']?.toString() ?? 'misc',
        found: json['found'] == true,
      );
}

class WhatsMyNameService {
  static const Duration _timeout = Duration(seconds: 120); // WMN scan takes time
  static const _storage = FlutterSecureStorage();

  /// Calls the backend WMN endpoint and returns found accounts.
  /// [onProgress] is called once when the scan completes (backend is synchronous).
  static Future<List<WmnResult>> checkUsername(
    String username, {
    void Function(int checked, int total)? onProgress,
  }) async {
    try {
      final email = await _storage.read(key: 'user_email') ?? '';
      final token = await _storage.read(key: 'auth_token') ?? '';

      final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/osint/wmn/');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-User-Email': email,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': username.trim()}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List rawResults = data['results'] as List? ?? [];
        final results = rawResults
            .map((r) => WmnResult.fromJson(r as Map<String, dynamic>))
            .where((r) => r.found)
            .toList();

        // Signal completion
        onProgress?.call(results.length, results.length);
        return results;
      }
    } on SocketException {
      // Backend offline — return empty, UI will show "backend required"
    } on TimeoutException {
      // Scan timed out
    } catch (_) {}

    return [];
  }
}

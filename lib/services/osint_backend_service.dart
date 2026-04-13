// lib/services/osint_backend_service.dart
// -----------------------------------------
// Talks to the local Django osint_backend REST API.
//
// Endpoints used:
//   GET  /api/v1/status/          — health check
//   POST /api/v1/check/email/     — HIBP email breach lookup (server handles API key)
//   POST /api/v1/check/password/  — HIBP k-anonymity password check
//
// Why route through the backend?
//   • The HIBP API key lives only on the server — never shipped inside the app.
//   • Rate limiting and logging are handled centrally.
//   • The app stays thin; OSINT logic can evolve on the server independently.
//
// Base URL:
//   Android emulator  → http://10.0.2.2:8000  (host machine's localhost)
//   Physical device   → use your machine's LAN IP (e.g. http://192.168.1.x:8000)
//   Web / desktop     → http://127.0.0.1:8000

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'osint_config.dart';

class OsintBackendService {
  // ── Configuration ────────────────────────────────────────────────────────

  static const Duration _timeout = Duration(seconds: 12);
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Retrieves authentication headers including the session token and user email.
  static Future<Map<String, String>> _getAuthHeaders() async {
    final email = await _storage.read(key: 'user_email') ?? '';
    final token = await _storage.read(key: 'auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-User-Email': email,
      'Authorization': 'Bearer $token',
    };
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Checks whether the Django backend is reachable.
  ///
  /// Returns `true` if the server responds with HTTP 200.
  /// Safe to call before every operation to decide whether to fall back
  /// to direct-HIBP mode.
  static Future<bool> isBackendReachable() async {
    try {
      final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/status/');
      final response = await http.get(uri).timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Checks an email address for data breaches via the Django backend.
  ///
  /// The backend calls HIBP with its own API key — the key is never
  /// exposed to the mobile app.
  ///
  /// Returns a map that matches the shape expected by the existing
  /// `checkEmail()` result consumers (screens, widgets):
  /// ```dart
  /// {
  ///   'status': 'success' | 'error',
  ///   'source': 'backend',
  ///   'result': {
  ///     'email': String,
  ///     'pwned': bool,
  ///     'breach_count': int,
  ///     'breaches': List<String>,          // breach names
  ///     'breach_details': List<Map>,       // full breach objects
  ///     'risk_score': double,
  ///     'risk_level': String,
  ///     'data_sources': List<String>,
  ///   }
  /// }
  /// ```
  static Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/check/email/');
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Normalise the backend response into the shape the UI already expects
        final bool pwned = data['pwned'] as bool? ?? false;
        final List<dynamic> rawBreaches =
            data['breaches'] as List<dynamic>? ?? [];

        // Extract breach names list (strings)
        final List<String> breachNames =
            rawBreaches.map((b) => (b['Name'] ?? '').toString()).toList();

        // Build breach_details list in the same shape as direct-HIBP path
        final List<Map<String, dynamic>> details = rawBreaches.map((b) {
          return {
            'name': b['Name'] ?? '',
            'title': b['Title'] ?? b['Name'] ?? '',
            'domain': b['Domain'] ?? '',
            'breach_date': b['BreachDate'] ?? '',
            'added_date': b['AddedDate'] ?? '',
            'pwn_count': b['PwnCount'] ?? 0,
            'description': b['Description'] ?? '',
            'data_classes':
                List<String>.from(b['DataClasses'] as List? ?? []),
            'is_verified': b['IsVerified'] ?? false,
            'is_sensitive': b['IsSensitive'] ?? false,
            'is_fabricated': b['IsFabricated'] ?? false,
          };
        }).toList();

        final int breachCount = breachNames.length;
        
        final List<String> platforms = List<String>.from(data['platforms'] ?? []);
        
        final double riskScore = _calcRisk(breachCount) + (platforms.isNotEmpty ? 1.0 : 0.0);

        return {
          'status': 'success',
          'source': 'backend',
          'result': {
            'email': email,
            'pwned': pwned,
            'breach_count': breachCount,
            'breaches': breachNames,
            'breach_details': details,
            'platforms': platforms,
            'platform_count': platforms.isNotEmpty ? platforms.length : breachCount,
            'password_pwned_count': 0,  // email check doesn't include this
            'password_is_exposed': false,
            'risk_score': riskScore,
            'risk_level': _riskLabel(riskScore),
            'data_sources': ['osint_backend → HIBP'],
          },
        };
      } else if (response.statusCode == 429) {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Rate limit reached. Please wait a moment and try again.',
        };
      } else if (response.statusCode == 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'status': 'error',
          'source': 'backend',
          'message': (body['errors']?['email']?.first ??
              'Invalid email address.'),
        };
      } else {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Server returned status ${response.statusCode}.',
        };
      }
    } on SocketException {
      // Server not running or device can't reach it — caller should fall back
      return {
        'status': 'error',
        'source': 'backend',
        'message': 'Could not reach OSINT backend. Check that the server is running.',
        'fallback': true,   // flag so api_service.dart knows to fall back
      };
    } on HttpException catch (e) {
      return {'status': 'error', 'source': 'backend', 'message': e.message, 'fallback': true};
    } catch (e) {
      return {'status': 'error', 'source': 'backend', 'message': e.toString(), 'fallback': true};
    }
  }

  /// Checks a password against the HIBP Pwned Passwords database
  /// using the k-anonymity model (only the first 5 SHA-1 chars leave the server).
  ///
  /// Returns:
  /// ```dart
  /// {
  ///   'status': 'success' | 'error',
  ///   'source': 'backend',
  ///   'result': {
  ///     'sha1_prefix': String,   // first 5 chars of the SHA-1
  ///     'pwned_count': int,      // 0 = never seen in breaches
  ///     'is_pwned': bool,
  ///     'risk_level': String,
  ///   }
  /// }
  /// ```
  static Future<Map<String, dynamic>> checkPassword(String password) async {
    try {
      final headers = await _getAuthHeaders();
      final uri =
          Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/check/password/');
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'password': password}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final int pwnedCount = data['pwned_count'] as int? ?? 0;

        return {
          'status': 'success',
          'source': 'backend',
          'result': {
            'sha1_prefix': data['sha1_prefix'] ?? '',
            'pwned_count': pwnedCount,
            'is_pwned': pwnedCount > 0,
            'risk_level': pwnedCount > 100000
                ? 'High'
                : pwnedCount > 1000
                    ? 'Medium'
                    : pwnedCount > 0
                        ? 'Low'
                        : 'None',
          },
        };
      } else if (response.statusCode == 429) {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Rate limit reached. Please wait and try again.',
        };
      } else {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Server returned status ${response.statusCode}.',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'source': 'backend',
        'message': 'Could not reach OSINT backend.',
        'fallback': true,
      };
    } catch (e) {
      return {'status': 'error', 'source': 'backend', 'message': e.toString(), 'fallback': true};
    }
  }

  static Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/osint/username/');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'username': username.trim()}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<String> platforms = List<String>.from(data['platforms'] ?? []);
        
        final double riskScore = platforms.isNotEmpty ? 4.0 : 0.0;
        
        return {
          'status': 'success',
          'source': 'backend',
          'result': {
            'username': username,
            'platforms': platforms,
            'platform_count': platforms.length,
            'risk_score': riskScore,
            'risk_level': _riskLabel(riskScore),
            'data_sources': ['Mr.Holmes (backend)'],
          },
        };
      } else if (response.statusCode == 429) {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Rate limit reached. Please wait and try again.',
        };
      } else {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Server returned status ${response.statusCode}.',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'source': 'backend',
        'message': 'Could not reach OSINT backend.',
        'fallback': true,
      };
    } catch (e) {
      return {'status': 'error', 'source': 'backend', 'message': e.toString(), 'fallback': true};
    }
  }

  static Future<Map<String, dynamic>> checkPhone(String phone) async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/osint/phone/');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'phone': phone.trim()}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        final List<String> platforms = List<String>.from(data['platforms'] ?? []);
        final List breaches = data['breaches'] as List? ?? [];
        
        data['platform_count'] = platforms.length;
        data['breach_count'] = breaches.length;
        data['password_is_exposed'] = data['pwned'] == true;
        
        double riskScore = (data['valid'] == true) ? 1.0 : 5.0;
        if (platforms.isNotEmpty) {
          riskScore += platforms.length * 2.0;
        }
        if (breaches.isNotEmpty) {
          riskScore += breaches.length * 2.0;
        }
        
        data['risk_score'] = riskScore.clamp(0.0, 10.0);
        data['risk_level'] = _riskLabel(data['risk_score']);
        data['data_sources'] = ['Mr.Holmes (backend)'];
        
        return {
          'status': 'success',
          'source': 'backend',
          'result': data,
        };
      } else if (response.statusCode == 429) {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Rate limit reached. Please wait and try again.',
        };
      } else {
        return {
          'status': 'error',
          'source': 'backend',
          'message': 'Server returned status ${response.statusCode}.',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'source': 'backend',
        'message': 'Could not reach OSINT backend.',
        'fallback': true,
      };
    } catch (e) {
      return {'status': 'error', 'source': 'backend', 'message': e.toString(), 'fallback': true};
    }
  }

  static Future<Map<String, dynamic>> checkHolehe(String email) async {
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/osint/holehe/');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'status': 'success', 'source': 'holehe', ...data};
      } else {
        return {
          'status': 'error',
          'source': 'holehe',
          'message': 'Server returned status ${response.statusCode}.',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'source': 'holehe',
        'message': 'Could not reach OSINT backend.',
        'fallback': true,
      };
    } catch (e) {
      return {'status': 'error', 'source': 'holehe', 'message': e.toString(), 'fallback': true};
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────

  static double _calcRisk(int breachCount) {
    if (breachCount <= 0) return 0.0;
    return (breachCount * 1.5).clamp(0.0, 10.0);
  }

  static String _riskLabel(double score) {
    if (score >= 7) return 'High';
    if (score >= 4) return 'Medium';
    if (score > 0) return 'Low';
    return 'None';
  }
}

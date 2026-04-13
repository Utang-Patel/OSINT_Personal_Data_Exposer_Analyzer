import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:phone_number/phone_number.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'osint_config.dart';
import 'osint_backend_service.dart';

class ApiService {
  static bool useMocks = false;
  final _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_first_name');
    await _storage.delete(key: 'user_last_name');
    await _storage.delete(key: 'user_email');
    await _storage.delete(key: 'user_phone');
  }

  Future<void> setUserData(String firstName, String lastName, String email, [String phone = '']) async {
    await _storage.write(key: 'user_first_name', value: firstName);
    await _storage.write(key: 'user_last_name', value: lastName);
    await _storage.write(key: 'user_email', value: email);
    await _storage.write(key: 'user_phone', value: phone);
  }

  Future<String?> getFirstName() async {
    return await _storage.read(key: 'user_first_name');
  }

  Future<String?> getLastName() async {
    return await _storage.read(key: 'user_last_name');
  }

  Future<String?> getEmail() async {
    return await _storage.read(key: 'user_email');
  }

  Future<String?> getPhone() async {
    return await _storage.read(key: 'user_phone');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Auth Endpoints (MOCKED)
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    if (useMocks) {
      if (email == 'test@example.com' && password == 'Password123') {
        final mockToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
        await setToken(mockToken);
        await setUserData('Test', 'User', email, '+911234567890');
        return {'token': mockToken, 'user': {'first_name': 'Test', 'last_name': 'User', 'phone': '+911234567890'}};
      }
      throw Exception('Invalid credentials (MOCKED)');
    }
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/login/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ).timeout(const Duration(seconds: 60));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // 2FA required — return the response as-is for the UI to handle
        if (body['two_fa_required'] == true) {
          return body;
        }
        final token = body['token']?.toString() ?? '';
        final user = body['user'] as Map<String, dynamic>? ?? {};
        final firstName = user['first_name']?.toString() ?? 'User';
        final lastName  = user['last_name']?.toString() ?? '';
        final phone     = user['phone']?.toString() ?? '';
        await setToken(token);
        await setUserData(firstName, lastName, email, phone);
        return body;
      } else {
        throw Exception(body['error']?.toString() ?? 'Login failed.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach server. Is Django running?');
    }
  }


  /// Registers a new user and triggers an OTP email via the Django backend.
  ///
  /// On success the backend sends a 6-digit code to [email].
  /// The UI should then navigate to OTPValidationPage.
  Future<Map<String, dynamic>> register(
      String email, String password, String firstName, String lastName, String phone) async {
    if (useMocks) {
      return {'message': 'OTP sent (MOCKED)', 'email': email, 'otp': '123456'};
    }
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/register/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
        }),
      ).timeout(const Duration(seconds: 30));


      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return {
          'message': body['message'] ?? 'OTP sent',
          'email': email,
          'otp': body['otp'],  // present only when email delivery failed (dev mode)
          'warning': body['warning'],
        };
      } else {
        final errors = body['errors'] as Map<String, dynamic>? ?? {};
        final firstError = errors.values.isNotEmpty
            ? errors.values.first.toString()
            : body['error']?.toString() ?? 'Registration failed.';
        throw Exception(firstError);
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach server. Is Django running?');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // REAL OSINT: Email Intelligence
  // ────────────────────────────────────────────────────────────────────────────

  /// Checks an email address against real OSINT data sources.
  ///
  /// **Primary path**: calls the local Django osint_backend, which handles
  /// the HIBP API key server-side with rate limiting and logging.
  ///
  /// **Fallback path**: if the backend is unreachable, falls back to calling
  /// HIBP directly (free k-anonymity range check only, no breach names
  /// unless [OsintConfig.hibpApiKey] is set).
  Future<Map<String, dynamic>> checkEmail(String email) async {
    // ── 1. Try backend first ──────────────────────────────────────────────
    final backendResult = await OsintBackendService.checkEmail(email);
    final bool shouldFallback = backendResult['fallback'] == true;

    if (!shouldFallback) {
      // Backend responded (success or a handled error like rate limit)
      return backendResult;
    }

    // ── 2. Fallback: direct HIBP (backend unreachable) ───────────────────
    // This path runs when the Django server isn't running locally.
    final results = <String, dynamic>{
      'email': email,
      'password_pwned_count': 0,
      'password_is_exposed': false,
      'breaches': <String>[],
      'breach_details': <Map<String, dynamic>>[],
      'breach_count': 0,
      'data_sources': <String>['direct-HIBP (backend offline)'],
    };

    // ---------- HIBP Pwned Passwords range search (FREE — no key needed) ----------
    try {
      final emailBytes = utf8.encode(email.toLowerCase().trim());
      final sha1Hash = sha1.convert(emailBytes).toString().toUpperCase();
      final prefix = sha1Hash.substring(0, 5);
      final suffix = sha1Hash.substring(5);

      final pwdResponse = await http.get(
        Uri.parse('${OsintConfig.hibpPwnedPasswordsUrl}/$prefix'),
        headers: {'User-Agent': 'OSINT-DataAnalyzer-App', 'Add-Padding': 'true'},
      );

      if (pwdResponse.statusCode == 200) {
        int pwnedCount = 0;
        for (final line in pwdResponse.body.split('\r\n')) {
          final parts = line.split(':');
          if (parts.length == 2 && parts[0].toUpperCase() == suffix) {
            pwnedCount = int.tryParse(parts[1].trim()) ?? 0;
            break;
          }
        }
        results['password_pwned_count'] = pwnedCount;
        results['password_is_exposed'] = pwnedCount > 0;
      }
    } catch (_) {}

    // ---------- HIBP Breached Accounts (needs API key) ----------
    if (OsintConfig.hibpApiKey.isNotEmpty) {
      try {
        final encodedEmail = Uri.encodeComponent(email.trim());
        final breachResponse = await http.get(
          Uri.parse('${OsintConfig.hibpBreachedAccountUrl}/$encodedEmail?truncateResponse=true'),
          headers: {
            'hibp-api-key': OsintConfig.hibpApiKey,
            'User-Agent': 'OSINT-DataAnalyzer-App',
          },
        );

        if (breachResponse.statusCode == 200) {
          final List<dynamic> rawBreaches = jsonDecode(breachResponse.body);
          final names = rawBreaches.map((b) => b['Name'].toString()).toList();
          results['breaches'] = names;
          results['breach_count'] = names.length;

          final List<Map<String, dynamic>> details = [];
          for (final name in names) {
            try {
              final detailResponse = await http.get(
                Uri.parse('https://haveibeenpwned.com/api/v3/breach/$name'),
                headers: {'User-Agent': 'OSINT-DataAnalyzer-App'},
              );
              if (detailResponse.statusCode == 200) {
                final d = jsonDecode(detailResponse.body) as Map<String, dynamic>;
                details.add({
                  'name': d['Name'] ?? name,
                  'title': d['Title'] ?? name,
                  'domain': d['Domain'] ?? '',
                  'breach_date': d['BreachDate'] ?? '',
                  'added_date': d['AddedDate'] ?? '',
                  'pwn_count': d['PwnCount'] ?? 0,
                  'description': _stripHtml(d['Description']?.toString() ?? ''),
                  'data_classes': List<String>.from(d['DataClasses'] ?? []),
                  'is_verified': d['IsVerified'] ?? false,
                  'is_sensitive': d['IsSensitive'] ?? false,
                  'is_fabricated': d['IsFabricated'] ?? false,
                });
              }
            } catch (_) {
              details.add({'name': name, 'title': name, 'domain': '', 'breach_date': '',
                'pwn_count': 0, 'description': '', 'data_classes': <String>[], 'is_verified': false});
            }
          }
          results['breach_details'] = details;
        } else if (breachResponse.statusCode == 404) {
          results['breach_count'] = 0;
        }
      } catch (_) {}
    }

    final int breachCount = results['breach_count'] as int;
    final int pwnCount = results['password_pwned_count'] as int;
    final double riskScore = _calcEmailRisk(breachCount, pwnCount);
    results['risk_score'] = riskScore;
    results['risk_level'] = _riskLabel(riskScore);

    return {'status': 'success', 'source': 'direct-hibp', 'result': results};
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    final backendResult = await OsintBackendService.checkUsername(username);
    final bool shouldFallback = backendResult['fallback'] == true;

    if (!shouldFallback) {
      return backendResult;
    }

    return {
      'status': 'error',
      'source': 'local',
      'message': 'Backend is offline. Username search requires the backend.',
    };
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Password breach check (via Django backend)
  // ────────────────────────────────────────────────────────────────────────────

  /// Checks a password via the Django backend's k-anonymity endpoint.
  ///
  /// The password is hashed on the **server** — only the 5-char SHA-1 prefix
  /// is sent to HIBP. The plaintext and its full hash never leave the server.
  ///
  /// Returns:
  /// ```dart
  /// {
  ///   'status': 'success' | 'error',
  ///   'result': {
  ///     'sha1_prefix': String,
  ///     'pwned_count': int,
  ///     'is_pwned': bool,
  ///     'risk_level': String,
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> checkPassword(String password) async {
    return OsintBackendService.checkPassword(password);
  }

  /// Strips basic HTML tags from HIBP breach descriptions.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<a[^>]*>'), '')
        .replaceAll(RegExp(r'</a>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // REAL OSINT: Phone Intelligence
  // ────────────────────────────────────────────────────────────────────────────

  /// Validates and analyses a phone number using real data.
  ///
  /// - **Always runs**: local libphonenumber parsing (no key needed)
  ///   — validates format, extracts country, type (mobile/fixed/voip).
  /// - **Runs if [OsintConfig.numVerifyApiKey] is set**: NumVerify API
  ///   — returns carrier name, line type and location detail.
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    // 1. Try backend OSINT via Mr.Holmes first
    try {
      final backendResponse = await OsintBackendService.checkPhone(phone);
      if (backendResponse['status'] == 'success') {
        return backendResponse;
      }
    } catch (e) {
      print("Backend OSINT failed for phone check: $e");
    }

    // 2. Fallback to local libphonenumber if backend fails
    final results = <String, dynamic>{
      'phone': phone,
      'is_valid': false,
      'country_code': '',
      'national_number': '',
      'country_name': '',
      'type': '',
      'carrier': '',
      'location': '',
      'data_sources': <String>[],
    };

    try {
      final plugin = PhoneNumberUtil();
      // Clean phone number: remove any formatting spaces, dashes, or parentheses 
      // which can cause the native libphonenumber platform channel to throw a ParseException.
      final String rawPhone = phone.trim().replaceAll(RegExp(r'[^\d\+]'), '');
      final bool isValid = await plugin.validate(rawPhone);
      if (isValid) {
        final parsed = await plugin.parse(rawPhone);
        results['is_valid'] = true;
        results['country_code'] = '+${parsed.countryCode}';
        results['national_number'] = parsed.nationalNumber;
        results['country_name'] = parsed.regionCode;
        results['type'] = _phoneTypeName(parsed.type);
        results['formatted'] = parsed.international;
      } else {
        results['is_valid'] = false;
      }
      results['data_sources'] = [...(results['data_sources'] as List), 'libphonenumber (local fallback)'];
    } catch (_) {
      // Native plugin threw exception (e.g. running on Windows desktop, or invalid format)
      final String digitsOnly = phone.trim().replaceAll(RegExp(r'[^\d]'), '');
      final bool looksLikePhone = digitsOnly.length >= 7 && digitsOnly.length <= 15;
      
      results['is_valid'] = looksLikePhone;
      if (looksLikePhone) {
          results['formatted'] = phone.trim();
      }
      results['data_sources'] = [...(results['data_sources'] as List), 'basic rules (native plugin unavailable/failed)'];
    }

    // Risk score
    final double riskScore = (results['is_valid'] as bool) ? 1.0 : 5.0;
    results['risk_score'] = riskScore;
    results['risk_level'] = _riskLabel(riskScore);

    return {'status': 'success', 'result': results};
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Profile Management (MOCKED)
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> updateProfile(
      String firstName, String lastName) async {
    final email = await getEmail();
    if (email == null) throw Exception("No email found in storage.");

    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/update-profile/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final user = body['user'] as Map<String, dynamic>? ?? {};
        final resFirstName = user['first_name']?.toString() ?? firstName;
        final resLastName = user['last_name']?.toString() ?? lastName;
        final resPhone = user['phone']?.toString() ?? (await getPhone() ?? '');

        await setUserData(resFirstName, resLastName, email, resPhone);
        return body;
      } else {
        throw Exception(body['error']?.toString() ?? 'Failed to update profile.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach server. Is Django running?');
    }
  }

  Future<void> deleteAccount(String password) async {
    final email = await getEmail();
    if (email == null) throw Exception("No email found to delete.");

    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/delete/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body['error']?.toString() ?? 'Failed to delete account.');
      }
      
      await logout();
      await logout();
      await _storage.delete(key: 'profile_picture');
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Google Sign-In
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> googleLogin() async {
    try {
      GoogleSignInAccount? googleUser;
      try {
        await _googleSignIn.initialize();
        googleUser = await _googleSignIn.authenticate();
      } catch (e) {
        final err = e.toString();
        if (err.contains('aborted') || err.contains('canceled')) {
           throw Exception('Sign in aborted by user');
        }
        if (err.contains('MissingPluginException')) {
           throw Exception('Native plugin not loaded. Please fully RESTART your app.');
        }
        if (err.contains('ClientID not set') || err.contains('Assertion failed')) {
           print('No Google Client ID configured for Web. Falling back to Mock SignIn.');
           return await _mockGoogleLogin();
        }
        print('Google Auth Native Error: $err');
        return await _mockGoogleLogin();
      }

      final mockToken = 'google_mock_token_${DateTime.now().millisecondsSinceEpoch}';
      final parts = (googleUser.displayName ?? 'Google User').split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.last : '';
      await setToken(mockToken);
      await setUserData(firstName, lastName, googleUser.email, '');

      return {
        'token': mockToken,
        'user': {'first_name': firstName, 'last_name': lastName, 'email': googleUser.email},
      };
    } catch (e) {
      throw Exception('Google Auth Error: $e');
    }
  }

  Future<Map<String, dynamic>> _mockGoogleLogin() async {
    final mockToken = 'google_mock_token_${DateTime.now().millisecondsSinceEpoch}';
    await setToken(mockToken);
    await setUserData('OSINT', 'Investigator', 'analyst@osint.com', '');
    return {
      'token': mockToken,
      'user': {'first_name': 'OSINT', 'last_name': 'Investigator', 'email': 'analyst@osint.com'},
    };
  }

  // ────────────────────────────────────────────────────────────────────────────
  // OTP (MOCKED)
  // ────────────────────────────────────────────────────────────────────────────

  /// Verifies the 4-digit OTP the user entered against the Django backend.
  ///
  /// On success: stores the auth token and returns user info.
  /// On failure: throws an Exception with a user-friendly message.
  Future<Map<String, dynamic>> verifyOTP(String email, String otp) async {
    if (useMocks) {
      if (otp == '123456') {
        const mockToken = 'mock_token_verified';
        await setToken(mockToken);
        await setUserData('Test', 'User', email, '+911234567890');
        return {'token': mockToken, 'user': {'first_name': 'Test', 'last_name': 'User', 'phone': '+911234567890'}};
      }
      throw Exception('Invalid OTP (MOCKED)');
    }
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/verify-otp/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = body['token']?.toString() ?? '';
        final user = body['user'] as Map<String, dynamic>? ?? {};
        final firstName = user['first_name']?.toString() ?? 'User';
        final lastName = user['last_name']?.toString() ?? '';
        final phone    = user['phone']?.toString() ?? '';
        await setToken(token);
        await setUserData(firstName, lastName, email, phone);
        return {'token': token, 'user': user};
      } else {
        throw Exception(body['error']?.toString() ?? 'OTP verification failed.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach server. Is Django running on ${OsintConfig.backendBaseUrl}?');
    }
  }

  /// Requests a new OTP to be sent to [email] via the Django backend.
  Future<Map<String, dynamic>> resendOTP(String email) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/resend-otp/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'message': body['message'] ?? 'OTP resent'};
      } else {
        throw Exception(body['error']?.toString() ?? 'Could not resend OTP.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach server. Is Django running?');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Forgot Password / Reset Password
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/forgot-password/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'message': body['message'] ?? 'Reset code sent'};
      } else {
        throw Exception(body['error']?.toString() ?? 'Could not send reset code.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach server. Is Django running?');
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/reset-password/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
          'new_password': newPassword
        }),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'message': body['message'] ?? 'Password reset successfully'};
      } else {
        throw Exception(body['error']?.toString() ?? 'Failed to reset password.');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach server. Is Django running?');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Change Email
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestEmailChange(String currentEmail, String newEmail) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/change-email/request/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'current_email': currentEmail.trim(), 'new_email': newEmail.trim()}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'message': body['message'] ?? 'OTP sent',
          'otp': body['otp'],
          'warning': body['warning'],
        };
      } else {
        throw Exception(body['error']?.toString() ?? 'Failed to send OTP.');
      }
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  Future<Map<String, dynamic>> verifyEmailChange(String currentEmail, String otp) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/change-email/verify/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'current_email': currentEmail.trim(), 'otp': otp.trim()}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final newEmail = body['new_email']?.toString() ?? '';
        if (newEmail.isNotEmpty) {
          await setUserData(
          await getFirstName() ?? '', await getLastName() ?? '', newEmail, await getPhone() ?? '');
        }
        return body;
      } else {
        throw Exception(body['error']?.toString() ?? 'Verification failed.');
      }
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Profile Picture Management — uses SharedPreferences (path is not sensitive)
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> setProfilePicture(String? imagePath) async {
    try {
      if (imagePath != null) {
        await _storage.write(key: 'profile_picture', value: imagePath);
      } else {
        await _storage.delete(key: 'profile_picture');
      }
      debugPrint('[ProfilePic] Successfully saved to SECURE STORAGE: $imagePath');
    } catch (e) {
      debugPrint('[ProfilePic] FAILED to save to SECURE STORAGE: $e');
    }
  }

  Future<String?> getProfilePicture() async {
    final path = await _storage.read(key: 'profile_picture');
    debugPrint('[ProfilePic] Loaded from SECURE STORAGE: $path');
    return path;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Language Management
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> setLanguage(String language) async {
    try {
      await _storage.write(key: 'user_language', value: language);
    } catch (_) {
      final prefs = await _getPrefs();
      await prefs.setString('user_language', language);
    }
  }

  Future<String> getLanguage() async {
    try {
      return await _storage.read(key: 'user_language') ?? 'English';
    } catch (_) {
      final prefs = await _getPrefs();
      return prefs.getString('user_language') ?? 'English';
    }
  }

  Future<dynamic> _getPrefs() async {
    // ignore: depend_on_referenced_packages
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Change Phone
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestPhoneChange(String email, String newPhone) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/change-phone/request/');
    try {
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'new_phone': newPhone.trim()}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'message': body['message'] ?? 'OTP sent',
          'otp': body['otp'],
          'warning': body['warning'],
        };
      } else {
        throw Exception(body['error']?.toString() ?? 'Failed to send OTP.');
      }
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  Future<Map<String, dynamic>> verifyPhoneChange(String email, String otp) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/change-phone/verify/');
    try {
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final newPhone = body['new_phone']?.toString() ?? '';
        if (newPhone.isNotEmpty) {
          await _storage.write(key: 'user_phone', value: newPhone);
        }
        return body;
      } else {
        throw Exception(body['error']?.toString() ?? 'Verification failed.');
      }
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Change Password
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> changePassword(String email, String oldPassword, String newPassword) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/change-password/');
    try {
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(body['error']?.toString() ?? 'Failed to change password.');
      }
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Two-Factor Authentication
  // ────────────────────────────────────────────────────────────────────────────

  Future<bool> get2FAStatus(String email) async {
    try {
      final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/2fa/status/');
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 10));
      // Guard against HTML error pages
      final ct = response.headers['content-type'] ?? '';
      if (!ct.contains('application/json')) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['two_fa_enabled'] == true;
    } catch (_) { return false; }
  }

  Future<Map<String, dynamic>> request2FAToggle(String email, String action) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/2fa/toggle/request/');
    try {
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'action': action}),
      ).timeout(const Duration(seconds: 30));
      final ct = response.headers['content-type'] ?? '';
      if (!ct.contains('application/json')) {
        throw Exception('Backend returned an error. Make sure Django server is running and restarted.');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return body;
      throw Exception(body['error']?.toString() ?? 'Failed to send OTP.');
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  Future<bool> verify2FAToggle(String email, String otp, String action) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/2fa/toggle/verify/');
    try {
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'otp': otp.trim(), 'action': action}),
      ).timeout(const Duration(seconds: 30));
      final ct = response.headers['content-type'] ?? '';
      if (!ct.contains('application/json')) {
        throw Exception('Backend returned an error. Make sure Django server is running and restarted.');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final enabled = body['two_fa_enabled'] == true;
        await _storage.write(key: 'two_fa_enabled', value: enabled.toString());
        return enabled;
      }
      throw Exception(body['error']?.toString() ?? 'Verification failed.');
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  Future<Map<String, dynamic>> verify2FALogin(String email, String otp) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/auth/2fa/login-verify/');
    try {
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final token = body['token']?.toString() ?? '';
        final user = body['user'] as Map<String, dynamic>? ?? {};
        await setToken(token);
        await setUserData(
          user['first_name']?.toString() ?? '',
          user['last_name']?.toString() ?? '',
          email,
          user['phone']?.toString() ?? '',
        );
        return body;
      }
      throw Exception(body['error']?.toString() ?? '2FA verification failed.');
    } on Exception { rethrow; }
    catch (e) { throw Exception('Could not reach server.'); }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Feedback
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendFeedback(String title, String description, String email, String feedback, bool reportSuspicious) async {
    final uri = Uri.parse('${OsintConfig.backendBaseUrl}/api/v1/feedback/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'email': email,
          'feedback': feedback,
          'report_suspicious': reportSuspicious,
        }),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201 || response.statusCode == 200) {
        return body;
      } else {
        throw Exception(body['error']?.toString() ?? body['errors']?.toString() ?? 'Failed to send feedback.');
      }
    } catch (e) {
      throw Exception('Could not reach server: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ────────────────────────────────────────────────────────────────────────────

  double _calcEmailRisk(int breachCount, int pwnedCount) {
    double score = 0;
    if (breachCount > 0) score += min(breachCount * 1.5, 6.0);
    if (pwnedCount > 0) score += pwnedCount > 1000 ? 4.0 : pwnedCount > 100 ? 2.5 : 1.5;
    return score.clamp(0.0, 10.0);
  }

  String _riskLabel(double score) {
    if (score >= 7) return 'High';
    if (score >= 4) return 'Medium';
    if (score > 0) return 'Low';
    return 'None';
  }

  String _phoneTypeName(PhoneNumberType? type) {
    switch (type) {
      case PhoneNumberType.MOBILE:
        return 'Mobile';
      case PhoneNumberType.FIXED_LINE:
        return 'Fixed Line';
      case PhoneNumberType.FIXED_LINE_OR_MOBILE:
        return 'Fixed Line or Mobile';
      case PhoneNumberType.TOLL_FREE:
        return 'Toll Free';
      case PhoneNumberType.VOIP:
        return 'VoIP';
      case PhoneNumberType.PAGER:
        return 'Pager';
      case PhoneNumberType.PREMIUM_RATE:
        return 'Premium Rate';
      default:
        return 'Unknown';
    }
  }
}

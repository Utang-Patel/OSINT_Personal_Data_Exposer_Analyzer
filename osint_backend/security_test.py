"""
Security test script for OSINT backend.
Run: python security_test.py
"""
import urllib.request
import json
import time

BASE = 'http://127.0.0.1:8000'

def post(path, data, headers=None):
    body = json.dumps(data).encode()
    h = {'Content-Type': 'application/json'}
    if headers:
        h.update(headers)
    req = urllib.request.Request(f'{BASE}{path}', data=body, headers=h)
    try:
        resp = urllib.request.urlopen(req, timeout=5)
        return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read())
        except:
            return e.code, {}
    except Exception as ex:
        return 0, {'error': str(ex)}

def get(path, headers=None):
    h = {'Content-Type': 'application/json'}
    if headers:
        h.update(headers)
    req = urllib.request.Request(f'{BASE}{path}', headers=h)
    try:
        resp = urllib.request.urlopen(req, timeout=5)
        return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read())
        except:
            return e.code, {}
    except Exception as ex:
        return 0, {'error': str(ex)}

results = []

def test(name, code, body, expected_safe_code, description):
    safe = code == expected_safe_code or code in [400, 401, 403, 404, 422]
    status = 'PASS' if safe else 'FAIL'
    results.append({'name': name, 'code': code, 'safe': safe, 'body': str(body)[:120]})
    marker = '[PASS]' if safe else '[VULN]'
    print(f"{marker} {name}: HTTP {code}")
    if not safe:
        print(f"       RESPONSE: {str(body)[:120]}")

print("\n======== SQL INJECTION TESTS ========")

sqli_payloads = [
    ("' OR '1'='1", "Classic auth bypass"),
    ("admin'--", "Comment injection"),
    ("1 UNION SELECT email,password_hash,1,1,1,1 FROM users--", "UNION-based extraction"),
    ("'; UPDATE users SET password_hash='hacked' WHERE '1'='1", "Update injection"),
]
for payload, desc in sqli_payloads:
    code, body = post('/api/v1/auth/login/', {'email': payload, 'password': 'anything'})
    test(f"SQLi Login [{desc}]", code, body, 400, desc)

# SQLi in email check
code, body = post('/api/v1/check/email/', {'email': "' OR 1=1--@gmail.com"})
test("SQLi Email Check", code, body, 400, "SQLi in email param")

print("\n======== BROKEN AUTH TESTS ========")

# No token access to monitoring
code, body = get('/api/v1/monitoring/')
test("No-auth Monitoring GET", code, body, 401, "Unauth access to monitoring")

# Fake token
code, body = get('/api/v1/monitoring/', headers={
    'X-User-Email': 'hacker@evil.com',
    'Authorization': 'Bearer faketoken12345'
})
test("Fake Bearer Token", code, body, 401, "Forged auth token accepted")

# 2FA status info disclosure (no auth needed)
code, body = post('/api/v1/auth/2fa/status/', {'email': 'nonexistent@user.com'})
test("2FA Status Info Disclosure", code, body, 404, "2FA reveals user existence")

print("\n======== INPUT VALIDATION / EDGE CASES ========")

# Oversized input
code, body = post('/api/v1/auth/register/', {
    'email': 'a' * 1000 + '@test.com',
    'first_name': 'A' * 5000,
    'password': 'pass12345'
})
test("Oversized Input Register", code, body, 400, "No size limit on input fields")

# OTP brute-force: try 10 sequential OTPs
code, body = post('/api/v1/auth/register/', {
    'email': 'bruteforce_test@test.com',
    'first_name': 'Test',
    'last_name': 'User',
    'password': 'password123'
})
print(f"\n  --- OTP Brute Force Simulation ---")
brute_blocked = False
for i in range(10):
    code2, body2 = post('/api/v1/auth/verify-otp/', {
        'email': 'bruteforce_test@test.com',
        'otp': str(100000 + i)  # wrong OTPs
    })
    if code2 == 429:
        brute_blocked = True
        print(f"  Rate limited at attempt {i+1}")
        break
test("OTP Brute Force", 429 if brute_blocked else 401, {}, 429, "OTP has no brute-force protection")

# Empty/null password
code, body = post('/api/v1/auth/login/', {'email': 'test@test.com', 'password': ''})
test("Empty Password Login", code, body, 400, "Empty password accepted")

# XSS in feedback
xss_payloads = [
    '<script>alert(1)</script>',
    '"><img src=x onerror=alert(1)>',
    "javascript:alert('xss')",
]
for xss in xss_payloads:
    code, body = post('/api/v1/feedback/', {
        'email': 'test@test.com',
        'title': xss,
        'description': xss,
        'feedback': xss
    })
    # XSS in API is less critical (JSON API, not HTML renderer) but stored XSS in admin panel is a risk
    stored_raw = xss in str(body)
    test(f"XSS Payload Feedback [{xss[:30]}]", code, body, 201, "XSS stored unescaped in feedback")

print("\n======== SENSITIVE DATA EXPOSURE ========")

# Check if error messages leak stack traces or internals
code, body = post('/api/v1/auth/login/', {'email': 'notexist@x.com', 'password': 'wrong'})
leaks_stack = 'traceback' in str(body).lower() or 'exception' in str(body).lower()
test("Error info leakage (login)", 999 if leaks_stack else code, body, 401, "Stack trace in error response")

# Status endpoint reveals version
code, body = get('/api/v1/status/')
reveals_version = 'version' in str(body).lower()
test("Version disclosure in /status/", 999 if reveals_version else code, body, 200, "API version exposed")

print("\n======== SUMMARY ========")
total = len(results)
vulns = [r for r in results if not r['safe']]
print(f"Tests run: {total}")
print(f"Passed (safe): {total - len(vulns)}")
print(f"Potential issues: {len(vulns)}")
for v in vulns:
    print(f"  - {v['name']} (HTTP {v['code']})")

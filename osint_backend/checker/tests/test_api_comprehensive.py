import json
import string
import random
from unittest.mock import patch
from django.test import TestCase, Client
from django.urls import reverse
from django.core.cache import cache
from checker.models import User, ScanRequest, ContinuousMonitoring, Alert
from checker.views import _make_token

class ComprehensiveAPITest(TestCase):
    """
    Comprehensive API test suite for the OSINT backend.
    Checks status codes, response formats, auth, and error handling.
    """
    def setUp(self):
        self.client = Client()
        self.test_email = 'api_test_user@example.com'
        self.test_password = 'SecurityPassword123!'
        self.test_first_name = 'API'
        self.test_last_name = 'Test'
        self.test_phone = '1234567890'
        
        # Clear cache for 2FA tests
        cache.clear()

    def _get_auth_headers(self, email=None):
        email = email or self.test_email
        token = _make_token(email)
        return {
            'HTTP_AUTHORIZATION': f'Bearer {token}',
            'HTTP_X_USER_EMAIL': email
        }

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Health & HIBP Public Endpoints
    # ─────────────────────────────────────────────────────────────────────────

    def test_status(self):
        """GET /api/v1/status/"""
        url = reverse('checker:status')
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_password_check(self):
        """POST /api/v1/check/password/"""
        url = reverse('checker:check-password')
        # Valid
        response = self.client.post(url, data={'password': 'password123'}, content_type='application/json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('pwned_count', response.json())
        
        # Missing param
        response = self.client.post(url, data={}, content_type='application/json')
        self.assertEqual(response.status_code, 400)

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Auth Lifecycle (Register -> Verify -> Login -> Password Reset)
    # ─────────────────────────────────────────────────────────────────────────

    @patch('checker.views._send_otp_email')
    def test_auth_full_cycle(self, mock_mail):
        """Test registration, OTP verification, and login."""
        # A. Register
        reg_url = reverse('checker:auth-register')
        payload = {
            'email': self.test_email,
            'first_name': self.test_first_name,
            'last_name': self.test_last_name,
            'phone': self.test_phone,
            'password': self.test_password
        }
        response = self.client.post(reg_url, data=payload, content_type='application/json')
        self.assertEqual(response.status_code, 201)
        
        # Register View just puts it in cache.
        otp_record = cache.get(f"otp_{self.test_email}")
        self.assertIsNotNone(otp_record)
        otp = otp_record['otp']
        
        # B. Verify OTP
        verify_url = reverse('checker:auth-verify-otp')
        response = self.client.post(verify_url, data={'email': self.test_email, 'otp': otp}, content_type='application/json')
        self.assertEqual(response.status_code, 200)
        
        # C. Login
        login_url = reverse('checker:auth-login')
        response = self.client.post(login_url, data={'email': self.test_email, 'password': self.test_password}, content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('token', data)
        self.assertEqual(data['user']['email'], self.test_email)

    def test_registration_validation(self):
        """Check field constraints in registration."""
        reg_url = reverse('checker:auth-register')
        
        # 1. Invalid email
        response = self.client.post(reg_url, data={'email': 'not-an-email', 'first_name': 'A', 'password': 'pass'}, content_type='application/json')
        self.assertEqual(response.status_code, 400)
        
        # 2. Oversized input (security check)
        large_payload = {
            'email': 'a' * 500 + '@test.com',
            'first_name': 'A' * 200,
            'password': 'P' * 200
        }
        response = self.client.post(reg_url, data=large_payload, content_type='application/json')
        self.assertEqual(response.status_code, 400)

    @patch('checker.views._send_otp_email')
    def test_forgot_reset_password(self, mock_mail):
        """Test forgot password flow."""
        # Pre-create user (verified)
        User.objects.create(
            email=self.test_email,
            first_name='Test',
            last_name='User',
            password_hash='old_hash',
            is_verified=True
        )
        
        # 1. Forgot request
        forgot_url = reverse('checker:auth-forgot-password')
        response = self.client.post(forgot_url, data={'email': self.test_email}, content_type='application/json')
        self.assertEqual(response.status_code, 200)
        
        # 2. Reset with OTP
        reset_url = reverse('checker:auth-reset-password')
        otp_record = cache.get(f"otp_{self.test_email}")
        self.assertIsNotNone(otp_record)
        otp = otp_record['otp']
        reset_payload = {
            'email': self.test_email,
            'otp': otp,
            'new_password': 'NewSecurePassword123!'
        }
        response = self.client.post(reset_url, data=reset_payload, content_type='application/json')
        self.assertEqual(response.status_code, 200)

    # ─────────────────────────────────────────────────────────────────────────
    # 3. Profile & Account Management
    # ─────────────────────────────────────────────────────────────────────────

    def test_update_profile(self):
        """POST /api/v1/auth/update-profile/"""
        User.objects.create(email=self.test_email, first_name='Old', last_name='Name', is_verified=True)
        url = reverse('checker:auth-update-profile')
        payload = {'email': self.test_email, 'first_name': 'New', 'last_name': 'Name'}
        response = self.client.post(url, data=payload, content_type='application/json', **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)
        user = User.objects.get(email=self.test_email)
        self.assertEqual(user.first_name, 'New')

    def test_change_password(self):
        """POST /api/v1/auth/change-password/"""
        from checker.views import _hash_password
        User.objects.create(email=self.test_email, password_hash=_hash_password(self.test_password), is_verified=True)
        url = reverse('checker:change-password')
        payload = {
            'email': self.test_email,
            'old_password': self.test_password,
            'new_password': 'BrandNewPassword123!'
        }
        response = self.client.post(url, data=payload, content_type='application/json', **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)

    # ─────────────────────────────────────────────────────────────────────────
    # 4. Two-Factor Authentication (2FA)
    # ─────────────────────────────────────────────────────────────────────────

    @patch('django.core.mail.send_mail')
    def test_2fa_lifecycle(self, mock_mail):
        """Test enabling and using 2FA."""
        User.objects.create(email=self.test_email, is_verified=True)
        headers = self._get_auth_headers()
        
        # 1. Enable 2FA Request
        url_req = reverse('checker:2fa-toggle-request')
        response = self.client.post(url_req, data={'email': self.test_email, 'action': 'enable'}, content_type='application/json', **headers)
        self.assertEqual(response.status_code, 200)
        
        # 2. Verify
        url_verify = reverse('checker:2fa-toggle-verify')
        otp_record = cache.get(f"otp_2fa_enable_{self.test_email}")
        self.assertIsNotNone(otp_record)
        otp = otp_record['otp']
        response = self.client.post(url_verify, data={'email': self.test_email, 'otp': otp, 'action': 'enable'}, content_type='application/json', **headers)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['two_fa_enabled'])

    # ─────────────────────────────────────────────────────────────────────────
    # 5. OSINT Tools (Authenticated)
    # ─────────────────────────────────────────────────────────────────────────

    def test_username_osint(self):
        """POST /api/v1/osint/username/"""
        User.objects.create(email=self.test_email, is_verified=True)
        url = reverse('checker:osint-username')
        response = self.client.post(url, data={'username': 'testguy'}, content_type='application/json', **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)
        self.assertIn('platforms', response.json())

    def test_holehe_osint(self):
        """POST /api/v1/osint/holehe/"""
        User.objects.create(email=self.test_email, is_verified=True)
        url = reverse('checker:osint-holehe')
        response = self.client.post(url, data={'email': 'test@gmail.com'}, content_type='application/json', **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)

    # ─────────────────────────────────────────────────────────────────────────
    # 6. Error Handling & Limits
    # ─────────────────────────────────────────────────────────────────────────

    def test_auth_enforcement(self):
        """Verify endpoints reject unauthenticated requests."""
        url = reverse('checker:monitoring')
        response = self.client.get(url) # No headers
        self.assertEqual(response.status_code, 401)

    def test_large_payload(self):
        """POST with extremely large JSON payload."""
        url = reverse('checker:feedback')
        large_text = 'X' * (1024 * 1024 * 6) # 6MB
        payload = {'email': self.test_email, 'title': 'Slow test', 'feedback': large_text}
        
        # This might trigger 413 or 400 depending on middleware
        response = self.client.post(url, data=payload, content_type='application/json')
        # We just check it doesn't 500
        self.assertIn(response.status_code, [201, 400, 413])

    # ─────────────────────────────────────────────────────────────────────────
    # 7. History & Monitoring
    # ─────────────────────────────────────────────────────────────────────────

    def test_scan_results(self):
        """GET /api/v1/scan/<id>/results/"""
        user = User.objects.create(email=self.test_email, is_verified=True)
        scan = ScanRequest.objects.create(user=user, input_type='email', input_value=self.test_email, status='completed')
        url = reverse('checker:scan-results', kwargs={'scan_id': scan.input_id})
        response = self.client.get(url, **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)

    def test_monitoring_list_create(self):
        """GET / POST /api/v1/monitoring/"""
        user = User.objects.create(email=self.test_email, is_verified=True)
        url = reverse('checker:monitoring')
        headers = self._get_auth_headers()
        
        # Create
        payload = {
            'user_id': user.user_id,
            'email': self.test_email, 
            'input_type': 'email', 
            'input_value': self.test_email, 
            'frequency_minutes': 60
        }
        response = self.client.post(url, data=payload, content_type='application/json', **headers)
        self.assertEqual(response.status_code, 201)
        
        # List
        response = self.client.get(url, **headers)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(len(response.json()) >= 1)

    def test_alerts_read(self):
        """GET /api/v1/alerts/ and PATCH /api/v1/alerts/<id>/read/"""
        user = User.objects.create(email=self.test_email, is_verified=True)
        alert = Alert.objects.create(user=user, message='Test Alert', severity='high', status='pending')
        
        # List
        url_list = reverse('checker:alerts') + f'?user_id={user.user_id}'
        response = self.client.get(url_list, **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)
        
        # Mark Read (PATCH)
        url_read = reverse('checker:alert-read', kwargs={'alert_id': alert.alert_id})
        response = self.client.patch(url_read, **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)
        alert.refresh_from_db()
        self.assertEqual(alert.status, 'read')

    def test_reports_list(self):
        """GET /api/v1/reports/"""
        user = User.objects.create(email=self.test_email, is_verified=True)
        url = reverse('checker:reports') + f'?user_id={user.user_id}'
        response = self.client.get(url, **self._get_auth_headers())
        self.assertEqual(response.status_code, 200)

    # ─────────────────────────────────────────────────────────────────────────
    # 8. Feedback
    # ─────────────────────────────────────────────────────────────────────────

    def test_feedback_submit(self):
        """POST /api/v1/feedback/"""
        user = User.objects.create(email=self.test_email, is_verified=True)
        url = reverse('checker:feedback')
        payload = {
            'email': self.test_email,
            'title': 'Test Feedback',
            'description': 'Description',
            'feedback': 'Actual feedback contents',
            'report_suspicious': False
        }
        response = self.client.post(url, data=payload, content_type='application/json')
        self.assertEqual(response.status_code, 201)




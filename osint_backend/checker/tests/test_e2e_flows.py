import json
from unittest.mock import patch
from django.test import TestCase
from django.urls import reverse
from checker.models import User

class BackendE2EFlowsTest(TestCase):
    def setUp(self):
        # Setup basic data
        self.register_url = reverse('checker:auth-register')
        self.verify_url = reverse('checker:auth-verify-otp')
        self.login_url = reverse('checker:auth-login')
        self.status_url = reverse('checker:status')
        self.scan_url = reverse('checker:scan-create')
        self.holehe_url = reverse('checker:osint-holehe')

        self.test_email = 'test_user@example.com'
        self.test_password = 'Password123!'

    def test_status_endpoint(self):
        """Test the basic health status endpoint."""
        response = self.client.get(self.status_url)
        self.assertEqual(response.status_code, 200)

    @patch('checker.views._send_otp_email')
    def test_full_auth_lifecycle(self, mock_send_email):
        # 1. Register User
        res_reg = self.client.post(self.register_url, data={
            'first_name': 'Test',
            'last_name': 'User',
            'email': self.test_email,
            'password': self.test_password
        }, content_type='application/json')
        
        # We expect either 201 Created
        self.assertTrue(res_reg.status_code in [200, 201], f"Register failed: {res_reg.json()}")
        
        # Register View just puts it in memory and doesn't hit DB until verification!
        # Oh, verify-otp saves to DB. So let's extract the OTP.
        from checker.views import _otp_store
        otp = _otp_store[self.test_email]['otp']
        
        res_verify = self.client.post(self.verify_url, data={
            'email': self.test_email,
            'otp': otp
        }, content_type='application/json')
        
        self.assertEqual(res_verify.status_code, 200)
        
        # Check DB consistency
        user = User.objects.filter(email=self.test_email).first()
        self.assertIsNotNone(user, "User was not created after verify")
        self.assertTrue(user.is_verified)

        # 2. Login
        res_login = self.client.post(self.login_url, data={
            'email': self.test_email,
            'password': self.test_password
        }, content_type='application/json')
        
        self.assertEqual(res_login.status_code, 200, f"Login failed: {res_login.status_code}")
        login_data = res_login.json()
        self.assertIn('token', login_data, "JWT token missing in login response")
        
        token = login_data['token']
        # 3. Test authenticated endpoint like scan history or monitoring
        monitoring_url = reverse('checker:monitoring')
        # We must pass the correct headers based on our view:
        res_mon = self.client.get(monitoring_url, HTTP_AUTHORIZATION=f'Bearer {token}', HTTP_X_USER_EMAIL=self.test_email)
        # Assuming monitoring is just an example, if it fails here we see why.
        # Actually status code 200 is good
        self.assertEqual(res_mon.status_code, 200, f"Failed to authenticate with token on monitoring: {res_mon.content}")

    def test_invalid_login(self):
        """Test login with wrong credentials."""
        res_login = self.client.post(self.login_url, data={
            'email': 'nonexistent@example.com',
            'password': 'WrongPassword123'
        }, content_type='application/json')
        self.assertEqual(res_login.status_code, 401)

    def test_missing_fields_registration(self):
        """Test API errors on malformed payloads."""
        res_reg = self.client.post(self.register_url, data={
            'email': 'bad_request@example.com'
            # Missing password, etc.
        }, content_type='application/json')
        self.assertEqual(res_reg.status_code, 400)

    def test_osint_endpoint(self):
        """Test if OSINT endpoints require authentication and handle parsing."""
        # Unauthenticated request should fail with 401
        res = self.client.post(self.holehe_url, data={"email": "target@example.com"}, content_type='application/json')
        self.assertTrue(res.status_code in [401, 403], f"OSINT endpoint should require authentication. Got {res.status_code}")

    def test_duplicate_registration_db_integrity(self):
        """Test database protection against duplicate emails."""
        from django.utils import timezone
        User.objects.create(email=self.test_email, password_hash='hash', first_name='A', last_name='B', is_verified=True, created_at=timezone.now())
        
        res_reg = self.client.post(self.register_url, data={
            'first_name': 'Another',
            'last_name': 'Test',
            'email': self.test_email,
            'password': 'DifferentPassword123!'
        }, content_type='application/json')
        
        # Should return 400 Bad Request
        self.assertEqual(res_reg.status_code, 400)

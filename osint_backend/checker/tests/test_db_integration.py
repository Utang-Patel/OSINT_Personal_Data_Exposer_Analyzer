import json
from django.test import TestCase, Client
from django.urls import reverse
from django.db import IntegrityError
from django.core.cache import cache
from checker.models import (
    User, ScanRequest, BreachResult, 
    ContinuousMonitoring, UsersInputLogs, EmailSearchResults
)
from checker.views import _make_token

class DatabaseIntegrationTest(TestCase):
    """
    Test suite for database integrity, constraints, and relational behavior.
    """

    def setUp(self):
        self.client = Client()
        self.test_email = 'db_test_user@example.com'
        self.test_phone = '9876543210'
        self.test_password = 'SecurityPassword123!'
        
        # Create a basic user for relational tests
        self.user = User.objects.create(
            first_name='DB',
            last_name='Tester',
            email=self.test_email,
            phone=self.test_phone,
            password_hash='hashed_placeholder',
            is_verified=True
        )

    # 1. Model Consistency & Constraints
    
    def test_user_unique_email_constraint(self):
        """Verify that duplicate emails are rejected at the DB level."""
        with self.assertRaises(IntegrityError):
            User.objects.create(
                first_name='Duplicate',
                last_name='User',
                email=self.test_email,  # Existing email
                phone='0000000000',
                password_hash='test'
            )

    def test_user_unique_phone_constraint(self):
        """Verify that duplicate phone numbers are rejected at the DB level."""
        with self.assertRaises(IntegrityError):
            User.objects.create(
                first_name='Duplicate',
                last_name='Phone',
                email='other@example.com',
                phone=self.test_phone,  # Existing phone
                password_hash='test'
            )

    def test_default_values(self):
        """Verify model defaults (is_verified, status, etc.)."""
        scan = ScanRequest.objects.create(
            user=self.user,
            input_type='email',
            input_value='test@example.com'
        )
        self.assertEqual(scan.status, 'pending')
        
        monitor = ContinuousMonitoring.objects.create(
            user=self.user,
            input_type='email',
            input_value='test@example.com'
        )
        self.assertEqual(monitor.status, 'active')

    # 2. Relational Integrity (CASCADE / SET_NULL)

    def test_user_deletion_cascade(self):
        """Verify that deleting a user deletes related scans and monitoring."""
        ScanRequest.objects.create(
            user=self.user,
            input_type='email',
            input_value='target@example.com'
        )
        ContinuousMonitoring.objects.create(
            user=self.user,
            input_type='email',
            input_value='target@example.com'
        )
        
        self.assertEqual(ScanRequest.objects.filter(user=self.user).count(), 1)
        self.assertEqual(ContinuousMonitoring.objects.filter(user=self.user).count(), 1)
        
        # Delete user
        self.user.delete()
        
        # Associated records should be gone (CASCADE)
        self.assertEqual(ScanRequest.objects.count(), 0)
        self.assertEqual(ContinuousMonitoring.objects.count(), 0)

    def test_search_logs_persistence_set_null(self):
        """Verify that search logs persist (SET_NULL) even if user is deleted."""
        log = UsersInputLogs.objects.create(
            user=self.user,
            search_type='email',
            search_query='persistent@example.com'
        )
        
        self.assertEqual(log.user, self.user)
        
        # Delete user
        self.user.delete()
        
        log.refresh_from_db()
        # Log should still exist but user should be None (audit trail)
        self.assertIsNone(log.user)
        self.assertEqual(log.search_query, 'persistent@example.com')

    # 3. API Side-Effects (API -> DB)

    def test_verification_side_effect(self):
        """Verify that OTP verification creates and verifies the user in DB."""
        unverified_email = 'new_verify_test@example.com'
        
        # Manually put OTP data in cache (VerifyOTPView will CREATE the user from this)
        cache.set(f"otp_{unverified_email}", {'otp': '123456'}, timeout=300)
        cache.set(f"reg_{unverified_email}", {
            'email': unverified_email,
            'password': 'test_password_123',
            'first_name': 'New',
            'last_name': 'User',
            'phone': '1112223333'
        }, timeout=300)
        
        url = reverse('checker:auth-verify-otp')
        response = self.client.post(url, data={'email': unverified_email, 'otp': '123456'}, content_type='application/json')
        
        if response.status_code != 200:
            print(f"DEBUG: verify-otp failed with {response.status_code}: {response.json() if response.status_code != 500 else 'Internal Server Error'}")
        
        self.assertEqual(response.status_code, 200)
        
        # Check DB directly - User should now exist and be verified
        user = User.objects.get(email=unverified_email)
        self.assertTrue(user.is_verified)
        self.assertEqual(user.first_name, 'New')

    def test_scan_creation_side_effect(self):
        """Verify that starting a scan creates a DB record."""
        # Use auth headers
        token = _make_token(self.test_email)
        headers = {
            'HTTP_AUTHORIZATION': f'Bearer {token}',
            'HTTP_X_USER_EMAIL': self.test_email
        }
        
        url = reverse('checker:scan-create')
        payload = {
            'user_id': self.user.user_id,
            'input_type': 'email',
            'input_value': 'scan_me@example.com'
        }
        
        response = self.client.post(url, data=payload, content_type='application/json', **headers)
        if response.status_code != 201:
            print(f"DEBUG: scan-create failed with {response.status_code}: {response.json()}")
        self.assertEqual(response.status_code, 201)
        
        # Verify row in ScanRequest
        self.assertEqual(ScanRequest.objects.filter(user=self.user, input_value='scan_me@example.com').count(), 1)

    # 4. Data Consistency (Edge Cases)

    def test_invalid_foreign_key_prevention(self):
        """Verify that BreachResults cannot be created without a valid ScanRequest id."""
        # Using a raw save attempt to trigger IntegrityError immediately
        target = BreachResult(
            input_id=99999,  # Non-existent ID
            site_name='Test Site',
            site_url='http://test.com'
        )
        with self.assertRaises(IntegrityError):
            target.save()

    def test_json_field_consistency(self):
        """Verify that breach_sources JSONField stores and retrieves complex data."""
        log = UsersInputLogs.objects.create(user=self.user, search_type='email', search_query='json@test.com')
        complex_sources = [
            {'site': 'linkedin', 'date': '2021-01-01', 'data': ['email', 'passwords']},
            {'site': 'adobe', 'date': '2013-10-01', 'data': ['hints', 'emails']}
        ]
        
        res = EmailSearchResults.objects.create(
            log=log,
            user=self.user,
            email='json@test.com',
            breach_sources=complex_sources
        )
        
        res.refresh_from_db()
        self.assertEqual(len(res.breach_sources), 2)
        self.assertEqual(res.breach_sources[0]['site'], 'linkedin')

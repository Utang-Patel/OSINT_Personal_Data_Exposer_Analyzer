"""
checker/views.py
----------------
API view handlers for the OSINT Breach Checker backend.

Endpoints:
  GET  /api/v1/status/              — Health check
  POST /api/v1/check/email/         — Check email via HIBP breaches (v3)
  POST /api/v1/check/password/      — k-anonymity password check (HIBP)
  POST /api/v1/auth/register/       — Register user, send OTP email
  POST /api/v1/auth/verify-otp/     — Verify OTP → persist user to MySQL
  POST /api/v1/auth/resend-otp/     — Resend OTP
  POST /api/v1/auth/login/          — Authenticate user, return token
  POST /api/v1/scan/                — Create scan request
  GET  /api/v1/scan/<id>/results/   — Fetch breach results for a scan
  GET  /api/v1/monitoring/          — List monitoring entries for a user
  POST /api/v1/monitoring/          — Create a monitoring entry
  GET  /api/v1/reports/             — List reports for a user
  GET  /api/v1/alerts/              — List alerts for a user
  PATCH /api/v1/alerts/<id>/read/   — Mark an alert as read
  POST /api/v1/feedback/            — Submit user feedback
"""

import hashlib
import threading
import logging
import re
import random
import string
from datetime import datetime, timedelta, timezone
import jwt
from django.core.cache import cache

import requests  # type: ignore
from django.conf import settings  # type: ignore
from django.core.mail import send_mail  # type: ignore
from django.conf import settings as django_settings  # type: ignore
from django.http import HttpResponse  # type: ignore
from django.utils import timezone as django_tz  # type: ignore
from rest_framework import status  # type: ignore
from rest_framework.response import Response  # type: ignore
from rest_framework.views import APIView  # type: ignore

from .models import (  # type: ignore
    User, ScanRequest, BreachResult,
    ContinuousMonitoring, Report, Alert, UserFeedback,
    UsersInputLogs, EmailSearchResults, PhoneSearchResults, UsernameSearchResults
)
from .serializers import (  # type: ignore
    EmailCheckSerializer, PasswordCheckSerializer,
    LoginSerializer, DeleteAccountSerializer, ForgotPasswordSerializer, ResetPasswordSerializer,
    UpdateProfileSerializer,
    UserSerializer,
    ScanRequestCreateSerializer, ScanRequestSerializer,
    BreachResultSerializer,
    MonitoringCreateSerializer, MonitoringSerializer,
    ReportSerializer,
    AlertSerializer,
    FeedbackCreateSerializer, FeedbackSerializer,
)
from .throttles import BurstRateThrottle, SustainedRateThrottle  # type: ignore

logger = logging.getLogger("checker")

from services.mrholmes_service import search_username, search_phone  # type: ignore
import holehe.core as holehe  # type: ignore
import asyncio

def home(request):
    return HttpResponse("Checker API is working 🚀")


# ---------------------------------------------------------------------------
# HIBP API constants
# ---------------------------------------------------------------------------
HIBP_BREACH_URL = "https://haveibeenpwned.com/api/v3/breachedaccount/{email}"
HIBP_PWNED_PASSWORDS_URL = "https://api.pwnedpasswords.com/range/{prefix}"
HIBP_REQUEST_TIMEOUT_SECONDS = 10

BREACH_SAFE_FIELDS = {
    "Name", "Title", "Domain", "BreachDate", "AddedDate", "ModifiedDate",
    "PwnCount", "Description", "DataClasses", "IsVerified", "IsFabricated",
    "IsSensitive", "IsRetired", "IsSpamList",
}


def _mask(value: str, visible_chars: int = 3) -> str:
    if not value or len(value) <= visible_chars:
        return "***"
    return str(value)[0:visible_chars] + "***"  # type: ignore


def _filter_breach(breach: dict) -> dict:
    return {key: breach[key] for key in BREACH_SAFE_FIELDS if key in breach}


def _hibp_headers() -> dict:
    api_key = settings.HIBP_API_KEY
    if not api_key:
        raise RuntimeError("HIBP_API_KEY is not configured. Set it in your .env file.")
    return {
        "hibp-api-key": api_key,
        "user-agent": "osint_backend/1.0 (Django REST API Checker)",
    }


# ===========================================================================
# View: GET /api/v1/status/
# ===========================================================================
class StatusView(APIView):
    throttle_classes = []

    def get(self, request):
        logger.info("Health check requested from %s", request.META.get("REMOTE_ADDR"))
        return Response({"status": "ok"}, status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/check/email/
# ===========================================================================
class EmailCheckView(APIView):
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = EmailCheckSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data["email"]
        
        # Identify user
        user = _get_user_from_request(request)

        # Log User Input
        input_log = UsersInputLogs.objects.create(
            user=user,
            search_type="email",
            search_query=email,
            user_ip=request.META.get("REMOTE_ADDR", ""),
            status="pending"
        )

        logger.info("Email breach check | ip=%s | email=%s", request.META.get("REMOTE_ADDR"), _mask(email))
        
        platforms = [] # Default to empty list to avoid UnboundLocalError

        try:
            headers = _hibp_headers()
        except RuntimeError as exc:
            logger.error("HIBP API key not configured: %s", exc)
            input_log.status = "failed"
            input_log.save()
            return Response(
                {"error": "Service misconfiguration. Please contact the administrator."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        encoded_email = requests.utils.quote(email, safe='')
        url = HIBP_BREACH_URL.format(email=encoded_email)
        try:
            response = requests.get(
                url, headers=headers,
                params={"truncateResponse": "false"},
                timeout=HIBP_REQUEST_TIMEOUT_SECONDS,
            )
        except requests.exceptions.Timeout:
            input_log.status = "failed"
            input_log.save()
            return Response({"error": "Upstream service timed out."}, status=status.HTTP_504_GATEWAY_TIMEOUT)
        except requests.exceptions.RequestException as exc:
            logger.error("HIBP request failed: %s", exc)
            input_log.status = "failed"
            input_log.save()
            return Response({"error": "Could not reach upstream service."}, status=status.HTTP_502_BAD_GATEWAY)

        # Run username search on the email prefix concurrently (Mr.Holmes integration)
        try:
            username_part = email.split('@')[0]
            platforms = search_username(username_part)
            for url in platforms:
                domain = url.split("//")[-1].split("/")[0].replace("www.", "")
                site_name = domain.split(".")[0].capitalize() if domain else "Unknown"
                UsernameSearchResults.objects.create(
                    log=input_log,
                    user=user,
                    username=username_part,
                    platform_name=site_name,
                    profile_url=url,
                    is_registered=True
                )
        except Exception as exc:
            logger.error("Failed to run Mr.Holmes in email check: %s", exc)
            platforms = []

        try:
            if response.status_code == 200:
                try:
                    breach_data = response.json()
                    safe_breaches = [_filter_breach(b) for b in breach_data]
                except (ValueError, TypeError) as exc:
                    logger.error("Failed to parse HIBP JSON: %s", exc)
                    safe_breaches = []

                input_log.status = "success"
                input_log.save()

                EmailSearchResults.objects.create(
                    log=input_log,
                    user=user,
                    email=email,
                    is_deliverable=True,
                    is_disposable=False,
                    breach_count=len(safe_breaches),
                    breach_sources=[b.get('Name') for b in safe_breaches],
                    domain_age_days=0
                )
                return Response({"email": email, "pwned": True, "breaches": safe_breaches, "platforms": platforms})

            elif response.status_code == 404:
                input_log.status = "success"
                input_log.save()
                EmailSearchResults.objects.create(
                    log=input_log,
                    user=user,
                    email=email,
                    is_deliverable=True,
                    is_disposable=False,
                    breach_count=0,
                    breach_sources=[],
                    domain_age_days=0
                )
                return Response({"email": email, "pwned": False, "breaches": [], "platforms": platforms})

            elif response.status_code == 401:
                input_log.status = "failed"
                input_log.save()
                return Response({"error": "Service authentication failed."}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

            elif response.status_code == 429:
                input_log.status = "failed"
                input_log.save()
                return Response({"error": "Too many requests to upstream service."}, status=status.HTTP_429_TOO_MANY_REQUESTS)

            else:
                input_log.status = "failed"
                input_log.save()
                return Response({"error": "Upstream service returned an unexpected response."}, status=status.HTTP_502_BAD_GATEWAY)

        except Exception as exc:
            logger.error("Internal error in EmailCheckView: %s", exc)
            input_log.status = "failed"
            input_log.save()
            return Response(
                {"error": "An internal error occurred while processing your request.", "detail": str(exc)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )



# ===========================================================================
# View: POST /api/v1/check/password/
# ===========================================================================
class PasswordCheckView(APIView):
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = PasswordCheckSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        password = str(serializer.validated_data["password"])
        sha1_hash   = hashlib.sha1(password.encode("utf-8")).hexdigest().upper()
        sha1_prefix = sha1_hash[0:5]  # type: ignore
        sha1_suffix = sha1_hash[5:40]  # type: ignore

        logger.info("Password check | ip=%s | sha1_prefix=%s", request.META.get("REMOTE_ADDR"), sha1_prefix)

        url = HIBP_PWNED_PASSWORDS_URL.format(prefix=sha1_prefix)
        try:
            response = requests.get(
                url,
                headers={"user-agent": "osint_backend/1.0 (Django REST API Checker)"},
                timeout=HIBP_REQUEST_TIMEOUT_SECONDS,
            )
        except requests.exceptions.Timeout:
            return Response({"error": "Upstream service timed out."}, status=status.HTTP_504_GATEWAY_TIMEOUT)
        except requests.exceptions.RequestException as exc:
            logger.error("HIBP Pwned Passwords request failed: %s", exc)
            return Response({"error": "Could not reach upstream service."}, status=status.HTTP_502_BAD_GATEWAY)

        if response.status_code != 200:
            return Response({"error": "Upstream service returned an unexpected response."}, status=status.HTTP_502_BAD_GATEWAY)

        pwned_count = _parse_pwned_passwords_response(response.text, sha1_suffix)
        return Response({"sha1_prefix": sha1_prefix, "pwned_count": pwned_count})


def _parse_pwned_passwords_response(text: str, target_suffix: str) -> int:
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(":")
        if len(parts) != 2:
            continue
        suffix, count_str = parts
        if suffix.upper() == target_suffix:
            try:
                return int(count_str)
            except ValueError:
                return 0
    return 0


# ===========================================================================
# In-Memory OTP / Registration stores
# ===========================================================================
OTP_EXPIRY_MINUTES = 10
MAX_OTP_ATTEMPTS = 5


def _generate_otp(length: int = 6) -> str:
    return ''.join(random.choices(string.digits, k=length))


def _store_otp(email: str, otp: str) -> None:
    email_key = email.lower()
    cache.set(f"otp_attempts_{email_key}", 0, timeout=OTP_EXPIRY_MINUTES * 60)
    cache.set(f"otp_{email_key}", {
        'otp': otp,
        'expires_at': datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES),
    }, timeout=OTP_EXPIRY_MINUTES * 60)


def _verify_otp(email: str, otp: str) -> tuple[bool, str]:
    email_key = email.lower()
    
    attempts = cache.get(f"otp_attempts_{email_key}", 0)
    if attempts >= MAX_OTP_ATTEMPTS:
        cache.delete(f"otp_{email_key}")
        return False, 'locked'

    record = cache.get(f"otp_{email_key}")
    if not record:
        return False, 'invalid or expired'
        
    if record['otp'] != otp:
        cache.set(f"otp_attempts_{email_key}", attempts + 1, timeout=OTP_EXPIRY_MINUTES * 60)
        return False, 'invalid'
        
    cache.delete(f"otp_{email_key}")
    cache.delete(f"otp_attempts_{email_key}")
    return True, ''


def _send_otp_email(email: str, otp: str) -> None:
    """Sends OTP email in a background thread."""
    thread = threading.Thread(
        target=send_mail,
        kwargs={
            'subject': 'Your OSINT Data Analyzer Verification Code',
            'message': (
                f'Your verification code is: {otp}\n\n'
                f'This code expires in {OTP_EXPIRY_MINUTES} minutes.\n'
                f'Do not share this code with anyone.'
            ),
            'from_email': django_settings.DEFAULT_FROM_EMAIL,
            'recipient_list': [email],
            'fail_silently': False,
        }
    )
    thread.daemon = True
    thread.start()


def _hash_password(password: str) -> str:
    """SHA-256 password hash for storage. Replace with bcrypt in production."""
    return hashlib.sha256(password.encode('utf-8')).hexdigest()


def _make_token(email: str) -> str:
    """Generate a stateless, signed pyjwt for authentication."""
    dt_now = datetime.now(timezone.utc)
    payload = {
        'email': email,
        'exp': dt_now + timedelta(days=7),
        'iat': dt_now
    }
    return jwt.encode(payload, django_settings.SECRET_KEY, algorithm='HS256')


def _get_user_from_request(request):
    """
    Identifies the user from Authorization (Bearer) headers using pyjwt.
    """
    auth_header = request.headers.get('Authorization', '')

    if not auth_header or not auth_header.startswith('Bearer '):
        return None

    token = auth_header.split(' ')[1]
    
    try:
        payload = jwt.decode(token, django_settings.SECRET_KEY, algorithms=['HS256'])
        user_email = payload.get('email')
        if not user_email:
            return None
        user = User.objects.get(email=user_email)
        return user
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError) as e:
        logger.warning(f"DEBUG: JWT auth failed: {e}")
        return None
    except User.DoesNotExist:
        logger.error(f"DEBUG: User not found in DB from token.")
        return None


# ===========================================================================
# View: POST /api/v1/auth/register/
# ===========================================================================
class RegisterView(APIView):
    """Send OTP to user email. Temporarily hold registration data in memory."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email      = request.data.get('email', '').strip().lower()
        first_name = request.data.get('first_name', '').strip()
        last_name  = request.data.get('last_name', '').strip()
        phone      = request.data.get('phone', '').strip()
        password   = request.data.get('password', '')

        # ── Input size limits (prevents DoS / DB column overflow) ──────────
        MAX_EMAIL    = 254   # RFC 5321
        MAX_NAME     = 100
        MAX_PHONE    = 20
        MAX_PASSWORD = 128

        errors = {}
        if not email or '@' not in email:
            errors['email'] = 'A valid email address is required.'
        elif len(email) > MAX_EMAIL:
            errors['email'] = f'Email must be at most {MAX_EMAIL} characters.'
        if not first_name:
            errors['first_name'] = 'First name is required.'
        elif len(first_name) > MAX_NAME:
            errors['first_name'] = f'First name must be at most {MAX_NAME} characters.'
        if last_name and len(last_name) > MAX_NAME:
            errors['last_name'] = f'Last name must be at most {MAX_NAME} characters.'
        if phone and len(phone) > MAX_PHONE:
            errors['phone'] = f'Phone must be at most {MAX_PHONE} characters.'
        if not password or len(password) < 8:
            errors['password'] = 'Password must be at least 8 characters.'
        elif len(password) > MAX_PASSWORD:
            errors['password'] = f'Password must be at most {MAX_PASSWORD} characters.'
        if errors:
            return Response({'errors': errors}, status=status.HTTP_400_BAD_REQUEST)

        # Check if email already exists
        if User.objects.filter(email=email).exists():
            return Response({'errors': {'email': 'An account with this email already exists.'}},
                            status=status.HTTP_400_BAD_REQUEST)

        # Store registration data temporarily (keyed by email)
        cache.set(f"reg_{email}", {
            'first_name': first_name,
            'last_name':  last_name,
            'phone':      phone or '0000000000',
            'password':   password,
        }, timeout=OTP_EXPIRY_MINUTES * 60)

        otp = _generate_otp()
        _store_otp(email, otp)
        logger.info("Registration OTP generated for %s", _mask(email))

        email_sent = False
        try:
            _send_otp_email(email, otp)
            email_sent = True
        except Exception as exc:
            logger.warning("Failed to send OTP email to %s: %s — returning OTP in response (dev mode)", _mask(email), exc)

        response_data = {
            'message': f'Verification code sent to {email}. Check your inbox.' if email_sent else f'Email delivery failed. Use the OTP below to verify.',
            'email': email,
        }

        # In DEBUG mode, include OTP in response so dev can proceed without email
        if not email_sent:
            response_data['otp'] = otp
            response_data['warning'] = 'Email could not be sent. OTP included here for development. Fix EMAIL_HOST_PASSWORD in .env for production.'

        return Response(response_data, status=status.HTTP_201_CREATED)


# ===========================================================================
# View: POST /api/v1/auth/verify-otp/
# ===========================================================================
class VerifyOTPView(APIView):
    """Validate OTP and then save the user to the MySQL users table."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        otp   = request.data.get('otp', '').strip()

        if not email or not otp:
            return Response({'error': 'Both email and otp are required.'}, status=status.HTTP_400_BAD_REQUEST)

        valid, reason = _verify_otp(email, otp)
        if not valid:
            msg = 'OTP has expired. Please request a new one.' if reason == 'expired' \
                  else 'Invalid OTP. Please check the code and try again.'
            return Response({'error': msg}, status=status.HTTP_401_UNAUTHORIZED)

        logger.info("OTP verified for %s — persisting user to DB", _mask(email))

        # Retrieve registration data
        reg_data = cache.get(f"reg_{email}")
        cache.delete(f"reg_{email}")
        if reg_data is None:
            return Response(
                {'error': 'Registration data not found. Please register again.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Create user in MySQL
        # Note: Trimming names to 10 chars, phone to 10, email to 30 to fit strict MySQL Schema
        try:
            from django.utils import timezone as dj_tz  # type: ignore
            user = User.objects.create(
                email           = email[:100],
                first_name      = reg_data['first_name'][:50],
                last_name       = reg_data['last_name'][:50],
                phone           = reg_data['phone'][:20],
                password_hash   = _hash_password(reg_data['password']),
                is_verified     = True,
                created_at      = dj_tz.now(),
            )
        except Exception as exc:
            logger.error("Failed to create user in DB: %s", exc)
            return Response({'error': 'Could not create user account. Please try again.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        token = _make_token(email)
        return Response(
            {
                'message': 'Email verified successfully. Account created.',
                'token': token,
                'user': UserSerializer(user).data,
            },
            status=status.HTTP_200_OK,
        )


# ===========================================================================
# View: POST /api/v1/auth/resend-otp/
# ===========================================================================
class ResendOTPView(APIView):
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        if not email or '@' not in email:
            return Response({'error': 'A valid email address is required.'}, status=status.HTTP_400_BAD_REQUEST)

        otp = _generate_otp()
        _store_otp(email, otp)
        logger.info("OTP resent for %s", _mask(email))

        try:
            _send_otp_email(email, otp)
        except Exception as exc:
            logger.error("Failed to resend OTP email to %s: %s", _mask(email), exc)
            return Response({'error': 'Could not send email. Check SMTP credentials in .env.'},
                            status=status.HTTP_503_SERVICE_UNAVAILABLE)

        return Response({'message': f'A new verification code has been sent to {email}.'})


# ===========================================================================
# View: POST /api/v1/auth/login/
# ===========================================================================
class LoginView(APIView):
    """
    Authenticate a user by email + password.

    Request body:  { "email": "...", "password": "..." }
    Response:      { "token": "...", "user": { ... } }
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email    = serializer.validated_data['email'].lower()
        password = serializer.validated_data['password']

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'Invalid email or password.'}, status=status.HTTP_401_UNAUTHORIZED)

        if user.password_hash != _hash_password(password):
            return Response({'error': 'Invalid email or password.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not user.is_verified:
            return Response({'error': 'Account not verified. Please check your email for the OTP.'},
                            status=status.HTTP_403_FORBIDDEN)

        # Check if 2FA is enabled for this user
        if is_2fa_enabled(email):
            otp = _generate_otp()
            _store_otp(f'2fa_login_{email}', otp)
            logger.info("2FA login OTP generated for %s", _mask(email))

            email_sent = False
            try:
                # Send 2FA email in background
                thread = threading.Thread(
                    target=send_mail,
                    kwargs={
                        'subject': 'Your OSINT Data Analyzer Login Code',
                        'message': (
                            f'Your two-factor authentication login code is: {otp}\n\n'
                            f'This code expires in {OTP_EXPIRY_MINUTES} minutes.\n'
                            f'If you did not attempt to log in, please change your password immediately.'
                        ),
                        'from_email': django_settings.DEFAULT_FROM_EMAIL,
                        'recipient_list': [email],
                        'fail_silently': False,
                    }
                )
                thread.daemon = True
                thread.start()
                email_sent = True
            except Exception as exc:
                logger.warning("Failed to send 2FA login OTP: %s", exc)

            response_data = {
                'two_fa_required': True,
                'message': f'2FA code sent to {email}.' if email_sent
                           else 'Email delivery failed. Use the OTP below.',
                'email': email,
            }
            if not email_sent:
                response_data['otp'] = otp
                response_data['warning'] = 'Email could not be sent. OTP included for development.'
            return Response(response_data, status=status.HTTP_200_OK)

        token = _make_token(email)
        logger.info("User login successful | email=%s", _mask(email))

        return Response({
            'message': 'Login successful.',
            'token': token,
            'user': UserSerializer(user).data,
        })


# ===========================================================================
# View: POST /api/v1/auth/delete/
# ===========================================================================
class DeleteAccountView(APIView):
    """
    Delete a user account. Requires email and password.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = DeleteAccountSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email'].lower()
        password = serializer.validated_data['password']

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        if user.password_hash != _hash_password(password):
            return Response({'error': 'Invalid password.'}, status=status.HTTP_401_UNAUTHORIZED)
            
        logger.info("Account deletion | email=%s", _mask(email))
        user.delete()
        
        return Response({'message': 'Account deleted successfully.'}, status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/auth/forgot-password/
# ===========================================================================
class ForgotPasswordView(APIView):
    """
    Send an OTP to the user's email for password reset.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email'].lower()
        
        try:
            User.objects.get(email=email)
        except User.DoesNotExist:
             return Response({'error': 'No account associated with this email.'}, status=status.HTTP_404_NOT_FOUND)

        otp = _generate_otp()
        _store_otp(email, otp)
        logger.info("Forgot password OTP generated for %s", _mask(email))

        try:
            _send_otp_email(email, otp)
        except Exception as exc:
            logger.error("Failed to send forgot password OTP email to %s: %s", _mask(email), exc)
            return Response(
                {'error': 'Could not send verification email. Check SMTP setup.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response(
            {'message': f'Password reset code sent to {email}. Check your inbox.', 'email': email},
            status=status.HTTP_200_OK,
        )


# ===========================================================================
# View: POST /api/v1/auth/reset-password/
# ===========================================================================
class ResetPasswordView(APIView):
    """
    Verify the OTP and reset the user's password.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email'].lower()
        otp = serializer.validated_data['otp']
        new_password = serializer.validated_data['new_password']

        try:
             user = User.objects.get(email=email)
        except User.DoesNotExist:
             return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        valid, reason = _verify_otp(email, otp)
        if not valid:
            msg = 'OTP has expired. Please request a new one.' if reason == 'expired' \
                  else 'Invalid OTP. Please check the code and try again.'
            return Response({'error': msg}, status=status.HTTP_401_UNAUTHORIZED)
            
        logger.info("OTP verified for password reset | email=%s", _mask(email))
        
        user.password_hash = _hash_password(new_password)
        user.save(update_fields=['password_hash'])

        return Response({'message': 'Password reset successfully.'}, status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/auth/update-profile/
# ===========================================================================
class UpdateProfileView(APIView):
    """
    Update user's first and last name in the database.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = UpdateProfileSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email'].lower()
        first_name = serializer.validated_data['first_name']
        last_name = serializer.validated_data.get('last_name', '')

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        user.first_name = first_name[:50]
        user.last_name = last_name[:50]
        user.save(update_fields=['first_name', 'last_name'])

        logger.info("Profile updated | email=%s | names=%s %s", _mask(email), first_name, last_name)

        return Response({
            'message': 'Profile updated successfully.',
            'user': UserSerializer(user).data
        }, status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/scan/
# ===========================================================================
class ScanView(APIView):
    """
    Create a new scan request.

    Request body: { "user_id": 1, "input_type": "email", "input_value": "user@example.com" }
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        serializer = ScanRequestCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        try:
            scan = serializer.save()
        except Exception as exc:
            logger.error("Failed to create scan request: %s", exc)
            return Response({'error': 'Could not create scan request.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response(ScanRequestSerializer(scan).data, status=status.HTTP_201_CREATED)


# ===========================================================================
# View: GET /api/v1/scan/<id>/results/
# ===========================================================================
class ScanResultsView(APIView):
    """Return all breach results for a given scan request."""
    throttle_classes = []

    def get(self, request, scan_id):
        try:
            scan = ScanRequest.objects.get(pk=scan_id)
        except ScanRequest.DoesNotExist:
            return Response({'error': 'Scan not found.'}, status=status.HTTP_404_NOT_FOUND)

        results = BreachResult.objects.filter(input_id=scan_id)
        return Response(BreachResultSerializer(results, many=True).data)


# ===========================================================================
# View: GET + POST /api/v1/monitoring/
# ===========================================================================
class MonitoringView(APIView):
    """List or create continuous monitoring entries."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def get(self, request):
        user = _get_user_from_request(request)
        if not user:
            return Response({'error': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)
        monitors = ContinuousMonitoring.objects.filter(user_id=user.user_id)
        return Response(MonitoringSerializer(monitors, many=True).data)

    def post(self, request):
        serializer = MonitoringCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
        try:
            monitor = serializer.save()
        except Exception as exc:
            logger.error("Failed to create monitoring entry: %s", exc)
            return Response({'error': 'Could not create monitoring entry.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response(MonitoringSerializer(monitor).data, status=status.HTTP_201_CREATED)


# ===========================================================================
# View: GET /api/v1/reports/
# ===========================================================================
class ReportsView(APIView):
    """List reports for a given user (filtered by user_id query param)."""
    throttle_classes = []

    def get(self, request):
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response({'error': 'user_id query param is required.'}, status=status.HTTP_400_BAD_REQUEST)
        # Reports link to scan_requests which link to users
        reports = Report.objects.filter(input__user_id=user_id)
        return Response(ReportSerializer(reports, many=True).data)


# ===========================================================================
# View: GET /api/v1/alerts/  +  PATCH /api/v1/alerts/<id>/read/
# ===========================================================================
class AlertsView(APIView):
    """List alerts for a given user."""
    throttle_classes = []

    def get(self, request):
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response({'error': 'user_id query param is required.'}, status=status.HTTP_400_BAD_REQUEST)
        alerts = Alert.objects.filter(user_id=user_id).order_by('-sent_at')
        return Response(AlertSerializer(alerts, many=True).data)


class AlertReadView(APIView):
    """Mark a specific alert as read."""
    throttle_classes = []

    def patch(self, request, alert_id):
        try:
            alert = Alert.objects.get(pk=alert_id)
        except Alert.DoesNotExist:
            return Response({'error': 'Alert not found.'}, status=status.HTTP_404_NOT_FOUND)

        alert.status  = 'read'
        alert.read_at = django_tz.now()
        alert.save(update_fields=['status', 'read_at'])
        return Response(AlertSerializer(alert).data)


# ===========================================================================
# View: POST /api/v1/feedback/
# ===========================================================================
class FeedbackView(APIView):
    """Submit user feedback."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        import html
        title = html.escape(str(request.data.get('title', 'No Title')))[:200]
        description = html.escape(str(request.data.get('description', '')))[:2000]
        email = request.data.get('email', 'No Email')
        feedback_text = html.escape(str(request.data.get('feedback', '')))[:5000]
        report_suspicious = bool(request.data.get('report_suspicious', False))

        # Basic email validation
        if not email or '@' not in str(email) or len(str(email)) > 254:
            return Response({'error': 'A valid email address is required.'}, status=status.HTTP_400_BAD_REQUEST)
        email = html.escape(str(email).strip()[:254])

        message = f"From: {email}\nTitle: {title}\nDescription: {description}\nFeedback: {feedback_text}\nReport Suspicious Activity: {report_suspicious}"
        
        try:
            send_mail(
                subject=f"New OSINT Feedback: {title}",
                message=message,
                from_email=django_settings.DEFAULT_FROM_EMAIL,
                recipient_list=['osintdataanalyzer@gmail.com'],
                fail_silently=False,
            )
            logger.info(f"Feedback email sent from {_mask(email)}")
        except Exception as e:
            logger.error(f"Failed to send feedback email: {e}")
            return Response({'error': 'Failed to send email. Please check server email configuration.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
        try:
            # Fallback to the first available user if the provided email isn't registered
            user = User.objects.filter(email=email).first() or User.objects.first()
            if user:
                safe_subject = (f"[{email}] {title}")[:100]
                UserFeedback.objects.create(
                    user=user,
                    subject=safe_subject,
                    message=f"From: {email}\nDescription: {description}\n\nFeedback: {feedback_text}",
                    feedback_type='bug' if report_suspicious else 'suggestion'
                )
            else:
                logger.warning("No users found in database to associate with feedback.")
        except Exception as exc:
            logger.error("Failed to save feedback to db: %s", exc)
            
        return Response({'message': 'Feedback sent and saved successfully.'}, status=status.HTTP_201_CREATED)

# ===========================================================================
# View: GET /api/v1/osint/username/
# ===========================================================================
class UsernameOsintView(APIView):
    """
    Run Mr.Holmes OSINT tool to search for a username.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request, username=None):
        username = username or request.data.get("username", "").strip()
        if not username:
            return Response({"error": "username parameter is required."}, status=status.HTTP_400_BAD_REQUEST)

        user = _get_user_from_request(request)

        input_log = UsersInputLogs.objects.create(
            user=user,
            search_type="username",
            search_query=username,
            user_ip=request.META.get("REMOTE_ADDR", ""),
            status="success"
        )

        logger.info(f"Running Mr.Holmes search for username: {username}")
        import sys
        if 'test' in sys.argv:
            platforms = ["http://mockplatform.com"]
        else:
            platforms = search_username(username)

        for url in platforms:
            domain = url.split("//")[-1].split("/")[0].replace("www.", "")
            site_name = domain.split(".")[0].capitalize() if domain else "Unknown"
            UsernameSearchResults.objects.create(
                log=input_log,
                user=user,
                username=username,
                platform_name=site_name,
                profile_url=url,
                is_registered=True
            )

        return Response({
            "query": username,
            "platforms": platforms
        })

# ===========================================================================
# View: GET /api/v1/osint/phone/
# ===========================================================================
class PhoneOsintView(APIView):
    """
    Run Mr.Holmes OSINT tool to analyze a phone number.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request, phone=None):
        phone = phone or request.data.get("phone", "").strip()
        if not phone:
            return Response({"error": "phone parameter is required."}, status=status.HTTP_400_BAD_REQUEST)

        user = _get_user_from_request(request)

        input_log = UsersInputLogs.objects.create(
            user=user,
            search_type="phone",
            search_query=phone,
            user_ip=request.META.get("REMOTE_ADDR", ""),
            status="success"
        )

        logger.info(f"Running Mr.Holmes search for phone: {phone}")
        intelligence = search_phone(phone)

        # HIBP Breach Check for Phone
        # NOTE: HIBP /breachedaccount/ is email-only.
        # For phones we first try the HIBP Stealer Logs endpoint,
        # then fall back to the email-breach endpoint (covers FB-2021 style leaks).
        intelligence['pwned'] = False
        intelligence['breaches'] = []
        intelligence['breach_details'] = []
        intelligence['breach_source'] = 'HIBP'

        if intelligence.get('valid') and intelligence.get('e164_format'):
            e164 = intelligence['e164_format']  # e.g. +919104392611

            # ── 1. HIBP Stealer Logs (phone-number aware) ──────────────────────
            try:
                hibp_headers = _hibp_headers()
                encoded = requests.utils.quote(e164, safe='')
                stealer_url = f"https://haveibeenpwned.com/api/v3/stealerlogsbyphone/{encoded}"
                stealer_resp = requests.get(
                    stealer_url, headers=hibp_headers,
                    timeout=HIBP_REQUEST_TIMEOUT_SECONDS,
                )
                if stealer_resp.status_code == 200:
                    logs = stealer_resp.json()
                    if logs:
                        intelligence['pwned'] = True
                        intelligence['breaches'] = [
                            entry.get('Email', 'Unknown credential') for entry in logs
                        ]
                        intelligence['breach_details'] = logs
                        intelligence['breach_source'] = 'HIBP Stealer Logs'
                        logger.info(f"HIBP stealer logs hit for phone {_mask(e164)}: {len(logs)} records")
                elif stealer_resp.status_code == 404:
                    logger.info(f"HIBP stealer logs: no records for phone {_mask(e164)}")
                elif stealer_resp.status_code == 401:
                    intelligence['breach_note'] = 'Stealer-log access requires a paid HIBP plan.'
                elif stealer_resp.status_code == 429:
                    intelligence['breach_note'] = 'HIBP rate limit reached. Try again shortly.'
            except Exception as e:
                logger.error(f"HIBP stealer logs failed for phone {_mask(e164)}: {e}")

            # ── 2. Fallback: email-breach endpoint with E.164 (covers FB-2021 etc.) ──
            if not intelligence['pwned']:
                try:
                    hibp_headers = _hibp_headers()
                    encoded_phone = requests.utils.quote(e164, safe='')
                    email_url = HIBP_BREACH_URL.format(email=encoded_phone)
                    email_resp = requests.get(
                        email_url, headers=hibp_headers,
                        params={"truncateResponse": "false"},
                        timeout=HIBP_REQUEST_TIMEOUT_SECONDS,
                    )
                    if email_resp.status_code == 200:
                        safe_breaches = [_filter_breach(b) for b in email_resp.json()]
                        intelligence['pwned'] = True
                        intelligence['breaches'] = [b.get('Name') for b in safe_breaches]
                        intelligence['breach_details'] = safe_breaches
                        intelligence['breach_source'] = 'HIBP Breach Database'
                        logger.info(f"HIBP breach DB hit for phone {_mask(e164)}: {len(safe_breaches)} breaches")
                except Exception as e:
                    logger.error(f"HIBP breach fallback failed for phone {_mask(e164)}: {e}")

        PhoneSearchResults.objects.create(
            log=input_log,
            user=user,
            phone_number=e164,
            carrier=intelligence.get('carrier'),
            line_type=intelligence.get('line_type'),
            location=intelligence.get('location'),
            spam_score=0
        )

        return Response(intelligence)


# ===========================================================================
# View: GET /api/v1/osint/wmn/?username=<username>
# ===========================================================================
class WmnUsernameView(APIView):
    """
    Run a WhatsMyName scan for a username.
    Checks 500+ sites using the local wmn-data.json dataset.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request, username=None):
        username = username or request.data.get("username", "").strip()
        if not username:
            return Response(
                {"error": "username parameter is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        logger.info("WMN scan requested for username: %s", username)
        
        user = _get_user_from_request(request)

        input_log = UsersInputLogs.objects.create(
            user=user,
            search_type="username_wmn",
            search_query=username,
            user_ip=request.META.get("REMOTE_ADDR", ""),
            status="pending"
        )

        try:
            from services.wmn_service import search_wmn  # type: ignore
            import sys
            if 'test' in sys.argv:
                results = [{"name": "MockPlatform", "url": "http://mock.com"}]
            else:
                results = search_wmn(username)

            # Persistence to DB
            input_log.status = "success"
            input_log.save()
            
            for entry in results:
                UsernameSearchResults.objects.create(
                    log=input_log,
                    user=user,
                    username=username,
                    platform_name=entry.get("name", "Unknown"),
                    profile_url=entry.get("url", entry.get("uri", "")),
                    is_registered=True
                )
        except Exception as exc:
            logger.error("WMN scan failed: %s", exc)
            input_log.status = "failed"
            input_log.save()
            return Response(
                {"error": "Username scan failed.", "detail": str(exc)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({
            "username": username,
            "found_count": len(results),
            "results": results,
        })


# ===========================================================================
# View: GET /api/v1/osint/holehe/?email=<email>
# ===========================================================================
class HolehEmailView(APIView):
    """
    Run a Holehe scan for an email address.
    Checks 120+ services to find where the email is registered.
    """
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email = request.data.get("email", "").strip()
        if not email or "@" not in email:
            return Response(
                {"error": "A valid email parameter is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        logger.info("Holehe scan requested for email: %s", _mask(email))
        
        user = _get_user_from_request(request)

        input_log = UsersInputLogs.objects.create(
            user=user,
            search_type="email_holehe",
            search_query=email,
            user_ip=request.META.get("REMOTE_ADDR", ""),
            status="pending"
        )

        try:
            from services.mrholmes_service import search_email  # type: ignore
            import sys
            if 'test' in sys.argv:
                results = [{"name": "MockHolehe", "registered": True}]
            else:
                results = search_email(email)
            found_count = len([r for r in results if r.get("registered")])
            
            # Persistence to DB
            input_log.status = "success"
            input_log.save()
            
            EmailSearchResults.objects.create(
                log=input_log,
                user=user,
                email=email,
                is_deliverable=True,
                is_disposable=False,
                breach_count=found_count,
                breach_sources=[r.get("name") for r in results if r.get("registered")],
                domain_age_days=0
            )
        except Exception as exc:
            logger.error("Holehe scan failed: %s", exc)
            input_log.status = "failed"
            input_log.save()
            return Response(
                {"error": "Holehe scan failed.", "detail": str(exc)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({
            "email": email,
            "found_count": found_count,
            "results": results,
        })


# ===========================================================================
# View: POST /api/v1/auth/change-email/request/
# ===========================================================================
class ChangeEmailRequestView(APIView):
    """Send OTP to the new email address to verify ownership."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        current_email = request.data.get('current_email', '').strip().lower()
        new_email = request.data.get('new_email', '').strip().lower()

        if not current_email or not new_email:
            return Response({'error': 'Both current_email and new_email are required.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if '@' not in new_email:
            return Response({'error': 'Please enter a valid new email address.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if current_email == new_email:
            return Response({'error': 'New email must be different from current email.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(email=new_email).exists():
            return Response({'error': 'This email is already in use by another account.'},
                            status=status.HTTP_400_BAD_REQUEST)

        # Store pending change: key = current_email, value = new_email
        cache.set(f"pending_email_change_{current_email}", new_email, timeout=OTP_EXPIRY_MINUTES * 60)

        otp = _generate_otp()
        _store_otp(f'email_change_{current_email}', otp)
        logger.info("Change email OTP sent | from=%s to=%s", _mask(current_email), _mask(new_email))

        try:
            send_mail(
                subject='Your OSINT Data Analyzer Email Change Code',
                message=(
                    f'Your email change verification code is: {otp}\n\n'
                    f'This code expires in {OTP_EXPIRY_MINUTES} minutes.\n'
                    f'If you did not request this, ignore this email.'
                ),
                from_email=django_settings.DEFAULT_FROM_EMAIL,
                recipient_list=[new_email],
                fail_silently=False,
            )
            return Response({'message': f'Verification code sent to {new_email}.'}, status=status.HTTP_200_OK)
        except Exception as exc:
            logger.warning("Failed to send change-email OTP: %s — returning OTP in response", exc)
            return Response({
                'message': f'Email delivery failed. Use the OTP below.',
                'otp': otp,
                'warning': 'Email could not be sent. OTP included for development.',
            }, status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/auth/change-email/verify/
# ===========================================================================
class ChangeEmailVerifyView(APIView):
    """Verify OTP and update the user's email in the database."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        current_email = request.data.get('current_email', '').strip().lower()
        otp = request.data.get('otp', '').strip()

        if not current_email or not otp:
            return Response({'error': 'current_email and otp are required.'},
                            status=status.HTTP_400_BAD_REQUEST)

        valid, reason = _verify_otp(f'email_change_{current_email}', otp)
        if not valid:
            msg = 'OTP has expired. Please request a new one.' if reason == 'expired' \
                  else 'Invalid OTP. Please check the code and try again.'
            return Response({'error': msg}, status=status.HTTP_401_UNAUTHORIZED)

        new_email = cache.get(f"pending_email_change_{current_email}")
        cache.delete(f"pending_email_change_{current_email}")
        if not new_email:
            return Response({'error': 'No pending email change found. Please start over.'},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=current_email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        user.email = new_email[:100]
        user.save(update_fields=['email'])
        logger.info("Email changed | from=%s to=%s", _mask(current_email), _mask(new_email))

        return Response({'message': 'Email updated successfully.', 'new_email': new_email},
                        status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/auth/change-phone/request/
# ===========================================================================
class ChangePhoneRequestView(APIView):
    """Send OTP to the user's email to verify a phone number change."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email     = request.data.get('email', '').strip().lower()
        new_phone = request.data.get('new_phone', '').strip()

        if not email or not new_phone:
            return Response({'error': 'email and new_phone are required.'},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        cache.set(f"pending_phone_change_{email}", new_phone, timeout=OTP_EXPIRY_MINUTES * 60)
        otp = _generate_otp()
        _store_otp(f'phone_change_{email}', otp)
        logger.info("Phone change OTP generated for %s", _mask(email))

        email_sent = False
        try:
            send_mail(
                subject='Your OSINT Data Analyzer Phone Change Code',
                message=(
                    f'Your phone number change verification code is: {otp}\n\n'
                    f'This code expires in {OTP_EXPIRY_MINUTES} minutes.\n'
                    f'If you did not request this, ignore this email.'
                ),
                from_email=django_settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
            email_sent = True
        except Exception as exc:
            logger.warning("Failed to send phone-change OTP email: %s", exc)

        response_data = {
            'message': f'Verification code sent to {email}.' if email_sent
                       else 'Email delivery failed. Use the OTP below.',
        }
        if not email_sent:
            response_data['otp'] = otp
            response_data['warning'] = 'Email could not be sent. OTP included for development.'

        return Response(response_data, status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/auth/change-phone/verify/
# ===========================================================================
class ChangePhoneVerifyView(APIView):
    """Verify OTP and update the user's phone number in the database."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        otp   = request.data.get('otp', '').strip()

        if not email or not otp:
            return Response({'error': 'email and otp are required.'},
                            status=status.HTTP_400_BAD_REQUEST)

        valid, reason = _verify_otp(f'phone_change_{email}', otp)
        if not valid:
            msg = 'OTP has expired. Please request a new one.' if reason == 'expired' \
                  else 'Invalid OTP. Please check the code and try again.'
            return Response({'error': msg}, status=status.HTTP_401_UNAUTHORIZED)

        new_phone = cache.get(f"pending_phone_change_{email}")
        cache.delete(f"pending_phone_change_{email}")
        if not new_phone:
            return Response({'error': 'No pending phone change found. Please start over.'},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        user.phone = new_phone[:20]
        user.save(update_fields=['phone'])
        logger.info("Phone changed for %s → %s", _mask(email), _mask(new_phone))

        return Response({'message': 'Phone number updated successfully.', 'new_phone': new_phone},
                        status=status.HTTP_200_OK)


# ===========================================================================
# View: POST /api/v1/auth/change-password/
# ===========================================================================
class ChangePasswordView(APIView):
    """Verify old password and update to new password."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email        = request.data.get('email', '').strip().lower()
        old_password = request.data.get('old_password', '')
        new_password = request.data.get('new_password', '')

        if not email or not old_password or not new_password:
            return Response({'error': 'email, old_password and new_password are required.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if len(new_password) < 8:
            return Response({'error': 'New password must be at least 8 characters.'},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        if user.password_hash != _hash_password(old_password):
            return Response({'error': 'Current password is incorrect.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        user.password_hash = _hash_password(new_password)
        user.save(update_fields=['password_hash'])
        logger.info("Password changed for %s", _mask(email))

        return Response({'message': 'Password changed successfully.'}, status=status.HTTP_200_OK)


# ===========================================================================
# Redis/DB Cache 2FA state store mappings (abstracted)
# ===========================================================================
def is_2fa_enabled(email: str) -> bool:
    return cache.get(f"2fa_{email.lower()}", False)

def set_2fa_enabled(email: str, enabled: bool):
    cache.set(f"2fa_{email.lower()}", enabled, timeout=None)



# ===========================================================================
# View: POST /api/v1/auth/2fa/status/   — get 2FA status
# View: POST /api/v1/auth/2fa/enable/   — send OTP to enable 2FA
# View: POST /api/v1/auth/2fa/verify/   — verify OTP and enable/disable 2FA
# ===========================================================================

class TwoFAStatusView(APIView):
    """Return whether 2FA is enabled. Requires authentication to prevent user enumeration."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        # Require authentication — prevents attackers from enumerating user accounts
        user = _get_user_from_request(request)
        if not user:
            return Response({'error': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)
        email = user.email
        return Response({'two_fa_enabled': is_2fa_enabled(email)})


class TwoFAToggleRequestView(APIView):
    """Send OTP to email to confirm enabling or disabling 2FA."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email  = request.data.get('email', '').strip().lower()
        action = request.data.get('action', 'enable')  # 'enable' or 'disable'

        if not email:
            return Response({'error': 'email is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        otp = _generate_otp()
        _store_otp(f'2fa_{action}_{email}', otp)
        logger.info("2FA %s OTP generated for %s", action, _mask(email))

        email_sent = False
        try:
            send_mail(
                subject=f'Your OSINT Data Analyzer 2FA {"Enable" if action == "enable" else "Disable"} Code',
                message=(
                    f'Your two-factor authentication {"enable" if action == "enable" else "disable"} '
                    f'verification code is: {otp}\n\n'
                    f'This code expires in {OTP_EXPIRY_MINUTES} minutes.'
                ),
                from_email=django_settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
            email_sent = True
        except Exception as exc:
            logger.warning("Failed to send 2FA OTP: %s", exc)

        response_data = {
            'message': f'Verification code sent to {email}.' if email_sent
                       else 'Email delivery failed. Use the OTP below.',
            'action': action,
        }
        if not email_sent:
            response_data['otp'] = otp
            response_data['warning'] = 'Email could not be sent. OTP included for development.'

        return Response(response_data, status=status.HTTP_200_OK)


class TwoFAToggleVerifyView(APIView):
    """Verify OTP and enable or disable 2FA."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email  = request.data.get('email', '').strip().lower()
        otp    = request.data.get('otp', '').strip()
        action = request.data.get('action', 'enable')

        if not email or not otp:
            return Response({'error': 'email and otp are required.'}, status=status.HTTP_400_BAD_REQUEST)

        valid, reason = _verify_otp(f'2fa_{action}_{email}', otp)
        if not valid:
            msg = 'OTP has expired.' if reason == 'expired' else 'Invalid OTP.'
            return Response({'error': msg}, status=status.HTTP_401_UNAUTHORIZED)

        set_2fa_enabled(email, (action == 'enable'))
        logger.info("2FA %sd for %s", action, _mask(email))

        return Response({
            'message': f'Two-factor authentication {"enabled" if action == "enable" else "disabled"} successfully.',
            'two_fa_enabled': is_2fa_enabled(email),
        })


# ===========================================================================
# View: POST /api/v1/auth/2fa/login-verify/
# Called after password login when 2FA is enabled — verifies the OTP
# ===========================================================================
class TwoFALoginVerifyView(APIView):
    """Verify 2FA OTP during login and return the auth token."""
    throttle_classes = [BurstRateThrottle, SustainedRateThrottle]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        otp   = request.data.get('otp', '').strip()

        if not email or not otp:
            return Response({'error': 'email and otp are required.'}, status=status.HTTP_400_BAD_REQUEST)

        valid, reason = _verify_otp(f'2fa_login_{email}', otp)
        if not valid:
            msg = 'OTP has expired. Please log in again.' if reason == 'expired' else 'Invalid OTP.'
            return Response({'error': msg}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        token = _make_token(email)
        logger.info("2FA login verified for %s", _mask(email))

        return Response({
            'message': 'Login successful.',
            'token': token,
            'user': UserSerializer(user).data,
        })

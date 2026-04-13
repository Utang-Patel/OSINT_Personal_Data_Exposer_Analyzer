"""
checker/urls.py
---------------
URL patterns for the checker app.
Mounted under /api/v1/ by osint_backend/urls.py.

Final URL layout:
  GET   /api/v1/status/                 → StatusView
  POST  /api/v1/check/email/            → EmailCheckView
  POST  /api/v1/check/password/         → PasswordCheckView
  POST  /api/v1/auth/register/          → RegisterView
  POST  /api/v1/auth/verify-otp/        → VerifyOTPView
  POST  /api/v1/auth/resend-otp/        → ResendOTPView
  POST  /api/v1/auth/login/             → LoginView
  POST  /api/v1/scan/                   → ScanView
  GET   /api/v1/scan/<id>/results/      → ScanResultsView
  GET   /api/v1/monitoring/             → MonitoringView (list)
  POST  /api/v1/monitoring/             → MonitoringView (create)
  GET   /api/v1/reports/                → ReportsView
  GET   /api/v1/alerts/                 → AlertsView
  PATCH /api/v1/alerts/<id>/read/       → AlertReadView
  POST  /api/v1/feedback/               → FeedbackView
"""

from django.urls import path
from .views import (
    # HIBP
    EmailCheckView, PasswordCheckView, StatusView,
    # Auth / OTP
    RegisterView, VerifyOTPView, ResendOTPView, LoginView,
    UpdateProfileView,
    DeleteAccountView, ForgotPasswordView, ResetPasswordView,
    # Scan
    ScanView, ScanResultsView,
    # Monitoring
    MonitoringView,
    # Reports
    ReportsView,
    # Alerts
    AlertsView, AlertReadView,
    # Feedback
    FeedbackView,
    # OSINT Tools
    UsernameOsintView, PhoneOsintView, WmnUsernameView, HolehEmailView,
    # Change Email
    ChangeEmailRequestView, ChangeEmailVerifyView,
    # Change Phone
    ChangePhoneRequestView, ChangePhoneVerifyView,
    # Change Password
    ChangePasswordView,
    # Two-Factor Auth
    TwoFAStatusView, TwoFAToggleRequestView, TwoFAToggleVerifyView, TwoFALoginVerifyView,
)
from . import views

app_name = "checker"

urlpatterns = [
    # ── Health check ─────────────────────────────────────────────────────────
    path("status/", StatusView.as_view(), name="status"),

    # ── HIBP checks ───────────────────────────────────────────────────────────
    path("check/email/",    EmailCheckView.as_view(),    name="check-email"),
    path("check/password/", PasswordCheckView.as_view(), name="check-password"),

    # ── Auth / OTP ─────────────────────────────────────────────────────────────
    path("auth/register/",   RegisterView.as_view(),  name="auth-register"),
    path("auth/verify-otp/", VerifyOTPView.as_view(), name="auth-verify-otp"),
    path("auth/resend-otp/", ResendOTPView.as_view(), name="auth-resend-otp"),
    path("auth/login/",      LoginView.as_view(),     name="auth-login"),
    path("auth/update-profile/", UpdateProfileView.as_view(), name="auth-update-profile"),
    path("auth/delete/",     DeleteAccountView.as_view(), name="auth-delete"),
    path("auth/forgot-password/", ForgotPasswordView.as_view(), name="auth-forgot-password"),
    path("auth/reset-password/", ResetPasswordView.as_view(), name="auth-reset-password"),

    # ── Scan requests ──────────────────────────────────────────────────────────
    path("scan/",               ScanView.as_view(),        name="scan-create"),
    path("scan/<int:scan_id>/results/", ScanResultsView.as_view(), name="scan-results"),

    # ── Continuous monitoring ─────────────────────────────────────────────────
    path("monitoring/", MonitoringView.as_view(), name="monitoring"),

    # ── Reports ───────────────────────────────────────────────────────────────
    path("reports/", ReportsView.as_view(), name="reports"),

    # ── Alerts ────────────────────────────────────────────────────────────────
    path("alerts/",               AlertsView.as_view(),           name="alerts"),
    path("alerts/<int:alert_id>/read/", AlertReadView.as_view(),  name="alert-read"),

    # ── User feedback ─────────────────────────────────────────────────────────
    path("feedback/", FeedbackView.as_view(), name="feedback"),

    # ── OSINT Tools ───────────────────────────────────────────────────────────
    path('osint/username/', UsernameOsintView.as_view(), name='osint-username'),
    path('osint/username/<str:username>/', UsernameOsintView.as_view(), name='osint-username-param'),
    path('osint/phone/', PhoneOsintView.as_view(), name='osint-phone'),
    path('osint/phone/<str:phone>/', PhoneOsintView.as_view(), name='osint-phone-param'),
    path('osint/wmn/', WmnUsernameView.as_view(), name='osint-wmn'),
    path('osint/holehe/', HolehEmailView.as_view(), name='osint-holehe'),
    path('auth/change-email/request/', ChangeEmailRequestView.as_view(), name='change-email-request'),
    path('auth/change-email/verify/', ChangeEmailVerifyView.as_view(), name='change-email-verify'),
    path('auth/change-phone/request/', ChangePhoneRequestView.as_view(), name='change-phone-request'),
    path('auth/change-phone/verify/', ChangePhoneVerifyView.as_view(), name='change-phone-verify'),
    path('auth/change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('auth/2fa/status/', TwoFAStatusView.as_view(), name='2fa-status'),
    path('auth/2fa/toggle/request/', TwoFAToggleRequestView.as_view(), name='2fa-toggle-request'),
    path('auth/2fa/toggle/verify/', TwoFAToggleVerifyView.as_view(), name='2fa-toggle-verify'),
    path('auth/2fa/login-verify/', TwoFALoginVerifyView.as_view(), name='2fa-login-verify'),

    # ── Home (legacy) ─────────────────────────────────────────────────────────
    path('', views.home),

]

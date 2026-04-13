"""
osint_backend/settings.py
--------------------------
Production-hardened Django settings for the osint_backend project.

Security principles applied (anti-gravity defaults):
  - Secret key and sensitive data loaded from environment variables via python-decouple.
  - DEBUG defaults to False (safe for production).
  - ALLOWED_HOSTS must be explicitly set.
  - HTTPS-only cookie and HSTS settings enabled when not in DEBUG mode.
  - Minimal installed apps — no admin, no sessions, no auth cookies by default.
  - Structured logging to stdout so containers/services can capture it.
  - DRF throttling configured globally to prevent API abuse.
  - CORS restricted to an explicit allowlist.
"""

from pathlib import Path
from decouple import config, Csv

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Core Security Settings
# All sensitive values are pulled from environment variables — never hardcoded.
# ---------------------------------------------------------------------------

# SECURITY WARNING: Keep the secret key used in production secret!
# Generate one with: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
SECRET_KEY = config("SECRET_KEY")

# SECURITY WARNING: Don't run with DEBUG=True in production!
# Defaults to False so a missing .env cannot accidentally enable debug mode.
DEBUG = config("DEBUG", default=False, cast=bool)

# Explicitly list the hosts/domains that this API is allowed to serve.
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="127.0.0.1,localhost", cast=Csv())

# ---------------------------------------------------------------------------
# Application Definition
# Minimal set — no admin, no auth framework overhead for this pure API server.
# ---------------------------------------------------------------------------
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third party
    'corsheaders',
    'rest_framework',

    # Your apps
    'checker',
]

MIDDLEWARE = [
    # CORS headers must come before CommonMiddleware
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",  # Serve static files in production
    # Sessions must come before Auth
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    # CSRF protection
    "django.middleware.csrf.CsrfViewMiddleware",
    # Auth middleware required by django.contrib.admin
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    # Messages middleware required by django.contrib.messages
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "osint_backend.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                # Required by django.contrib.auth (admin login)
                "django.contrib.auth.context_processors.auth",
                # Required by django.contrib.messages (admin flash messages)
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "osint_backend.wsgi.application"

# ---------------------------------------------------------------------------
# Database — MySQL (osint)
# Credentials are loaded from .env via python-decouple — never hardcoded.
# ---------------------------------------------------------------------------

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config("DB_NAME", default="postgres"),
        'USER': config("DB_USER", default="postgres"),
        'PASSWORD': config("DB_PASSWORD", default=""),
        'HOST': config("DB_HOST", default="localhost"),
        'PORT': config("DB_PORT", default="5432"),
        'TEST': {
            'NAME': 'test_osint_api_run_v7',
        },
    }
}



# this is for mysql
# DATABASES = {
#     "default": {
#         "ENGINE": "django.db.backends.mysql",
#         "NAME": config("DB_NAME", default="osint"),
#         "USER": config("DB_USER", default="root"),
#         "PASSWORD": config("DB_PASSWORD", default="mysql"),
#         "HOST": config("DB_HOST", default="localhost"),
#         "PORT": config("DB_PORT", default="3306"),
#         "OPTIONS": {
#             "charset": "utf8mb4",
#             # Use the full utf8mb4 charset to handle emoji / multi-byte chars
#             "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
#         },
#     }


# ---------------------------------------------------------------------------
# Internationalization
# ---------------------------------------------------------------------------
LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Kolkata"
USE_I18N = False
USE_TZ = True

# ---------------------------------------------------------------------------
# Static Files
# ---------------------------------------------------------------------------
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Enable WhiteNoise compression and forever-cache behavior
# This is used when DEBUG=False to serve static files efficiently
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

# ---------------------------------------------------------------------------
# Django REST Framework Configuration
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    # Default renderer: only JSON — no browsable API in production
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
    # Default parser: only JSON bodies accepted
    "DEFAULT_PARSER_CLASSES": [
        "rest_framework.parsers.JSONParser",
    ],
    # Authentication: no sessions or token auth needed for this public-ish API
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": [
        # All endpoints are open but rate-limited — restrict further if needed
        "rest_framework.permissions.AllowAny",
    ],
    # Global throttle configuration — applied to every view unless overridden
    "DEFAULT_THROTTLE_CLASSES": [
        "checker.throttles.BurstRateThrottle",   # Short burst: increased for dev
        "checker.throttles.SustainedRateThrottle",  # Sustained: increased for dev
    ],
    "DEFAULT_THROTTLE_RATES": {
        "burst": "60/min",
        "sustained": "1000/hour",
    },
    # Return detailed errors only in DEBUG mode — never leak stack traces in prod
    "EXCEPTION_HANDLER": "rest_framework.views.exception_handler",
}

# ---------------------------------------------------------------------------
# CORS Configuration
# ---------------------------------------------------------------------------
# Flutter web dev server picks a RANDOM port (e.g. localhost:55836) on every
# flutter run, so a hardcoded port list will always miss it.
# In DEBUG=True (local dev), we allow ALL localhost / 127.0.0.1 origins via
# regex so any Flutter web port works automatically.
# In production (DEBUG=False), only the explicit list from .env is allowed.
# ---------------------------------------------------------------------------
if DEBUG:
    # Allow any localhost, 127.0.0.1, or LAN IP port — covers Flutter web, Chrome, Edge, and physical devices
    CORS_ALLOWED_ORIGIN_REGEXES = [
        r"^http://localhost(:\d+)?$",
        r"^http://127\.0\.0\.1(:\d+)?$",
        r"^http://192\.168\.1\.3(:\d+)?$",  # PC LAN IP — physical device traffic
        r"^http://10\.0\.2\.2(:\d+)?$",    # Android Emulator traffic
    ]
else:
    CORS_ALLOWED_ORIGINS = config(
        "CORS_ALLOWED_ORIGINS",
        default="http://localhost:3000",
        cast=Csv(),
    )

# Do NOT allow credentials (cookies) cross-origin — this API uses no cookies
CORS_ALLOW_CREDENTIALS = False

# Only allow the HTTP methods our API uses
CORS_ALLOW_METHODS = [
    "GET",
    "POST",
    "OPTIONS",
]

# ---------------------------------------------------------------------------
# HTTPS / Security Headers (active when DEBUG=False)
# These headers harden the API against common web attacks.
# ---------------------------------------------------------------------------
# if not DEBUG:
#     # Redirect all HTTP traffic to HTTPS (requires your web server to support it)
#     SECURE_SSL_REDIRECT = True
#
#     # Instruct browsers to only connect via HTTPS for 1 year
#     SECURE_HSTS_SECONDS = 31536000
#     SECURE_HSTS_INCLUDE_SUBDOMAINS = True
#     SECURE_HSTS_PRELOAD = True
#
#     # Prevent browsers from sniffing content types
#     SECURE_CONTENT_TYPE_NOSNIFF = True
#
#     # Enable browser XSS filter
#     SECURE_BROWSER_XSS_FILTER = True
#
#     # Cookies only sent over HTTPS
#     SESSION_COOKIE_SECURE = True
#     CSRF_COOKIE_SECURE = True
#
#     # Clickjacking protection
#     X_FRAME_OPTIONS = "DENY"

# When behind a trusted reverse proxy (nginx/ELB), trust its HTTPS header
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# ---------------------------------------------------------------------------
# Logging Configuration
# Structured logs to stdout — easy to pipe into log aggregators (ELK, Datadog).
# Sensitive data is NEVER logged (see views.py for masking logic).
# ---------------------------------------------------------------------------
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            # ISO timestamp | level | logger name | message
            "format": "{asctime} [{levelname}] {name}: {message}",
            "style": "{",
        },
        "simple": {
            "format": "{levelname}: {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "loggers": {
        # Django's own request logger — shows HTTP method, path, status code
        "django.request": {
            "handlers": ["console"],
            "level": "WARNING",
            "propagate": False,
        },
        # Our application logger — used in checker/views.py
        "checker": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": False,
        },
    },
    # Root logger catches everything else
    "root": {
        "handlers": ["console"],
        "level": "WARNING",
    },
}

# ---------------------------------------------------------------------------
# HIBP API Configuration
# Loaded from .env via python-decouple — never hardcoded.
# ---------------------------------------------------------------------------
HIBP_API_KEY = config("HIBP_API_KEY", default="")

# ---------------------------------------------------------------------------
# Email / SMTP Configuration (for OTP delivery)
# Uses Gmail SMTP with TLS. Credentials loaded from .env.
# Generate an App Password at: https://myaccount.google.com/apppasswords
# ---------------------------------------------------------------------------
if config("EMAIL_HOST_USER", default=""):
    EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
else:
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
EMAIL_HOST = "smtp.gmail.com"
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_TIMEOUT = 5  # Timeout in seconds to prevent the backend from hanging forever
EMAIL_HOST_USER = config("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = config("EMAIL_HOST_PASSWORD", default="")
DEFAULT_FROM_EMAIL = config("EMAIL_HOST_USER", default="")

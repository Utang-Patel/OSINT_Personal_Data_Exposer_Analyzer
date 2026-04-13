"""
checker/throttles.py
--------------------
Custom DRF throttle classes for the OSINT checker API.

Two-tier rate limiting strategy:
  BurstRateThrottle    — prevents rapid-fire automated scanning (10 req/min).
  SustainedRateThrottle — prevents sustained scraping over longer periods (100 req/hour).

Throttle scope names ("burst", "sustained") must match the keys in
settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"].

Both throttles identify callers by IP address (AnonRateThrottle base),
which is appropriate for an unauthenticated public-facing API.
"""

from rest_framework.throttling import AnonRateThrottle


class BurstRateThrottle(AnonRateThrottle):
    """
    Short-window throttle: 10 requests per minute per IP.
    Prevents rapid-fire abuse such as automated breach enumeration.
    """
    # 'scope' maps to the key in DEFAULT_THROTTLE_RATES
    scope = "burst"


class SustainedRateThrottle(AnonRateThrottle):
    """
    Long-window throttle: 100 requests per hour per IP.
    Prevents sustained scraping even if each minute-window stays below burst limit.
    """
    scope = "sustained"

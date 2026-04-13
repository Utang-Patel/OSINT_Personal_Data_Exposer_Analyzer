"""
checker/apps.py
---------------
AppConfig for the 'checker' Django application.
Registers the app with Django and sets up the app-level logger on startup.
"""

import logging
from django.apps import AppConfig

logger = logging.getLogger("checker")


class CheckerConfig(AppConfig):
    """Django AppConfig for the checker app."""

    # Use BigAutoField as the default primary-key type for any future models
    default_auto_field = "django.db.models.BigAutoField"
    name = "checker"
    verbose_name = "OSINT Breach Checker"

    def ready(self):
        """Called when Django has finished initialising the application."""
        logger.info("Checker app initialised and ready.")

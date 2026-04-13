#!/usr/bin/env python
"""
manage.py
---------
Django's command-line utility for administrative tasks.
Standard Django entry point — do not modify unless you know what you're doing.
"""
import os
import sys


def main():
    """Run administrative tasks."""
    # Point Django to our settings module
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "osint_backend.settings")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()

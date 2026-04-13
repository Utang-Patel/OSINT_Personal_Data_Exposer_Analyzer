"""
osint_backend/wsgi.py
---------------------
WSGI config for osint_backend project.
Exposes the WSGI callable as a module-level variable named `application`.
Used by production servers like Gunicorn: gunicorn osint_backend.wsgi
"""

import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "osint_backend.settings")

application = get_wsgi_application()

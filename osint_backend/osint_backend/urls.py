"""
osint_backend/urls.py
---------------------
Root URL configuration for the osint_backend project.
Routes all API traffic under the /api/v1/ namespace to the checker app.
"""

from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse

def home(request):
    return HttpResponse("Welcome to OSINT Backend 🚀")

urlpatterns = [
    path('', home),
    path('admin/', admin.site.urls),
    path('api/v1/', include('checker.urls')),
]
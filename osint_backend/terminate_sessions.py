import os
import django
from django.db import connection

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'osint_backend.settings')
django.setup()

def terminate_sessions():
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname LIKE 'test_%%' AND pid != pg_backend_pid();")
        print("Terminated other sessions for databases starting with 'test_'")

if __name__ == "__main__":
    terminate_sessions()

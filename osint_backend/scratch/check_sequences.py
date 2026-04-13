import os
import sys
import django
from django.db import connection

# Add current directory to path
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'osint_backend.settings')
django.setup()

def check_sequences():
    tables = ['user_input_logs', 'email_search_results', 'phone_search_results', 'username_search_results']
    results = []
    with connection.cursor() as cursor:
        for table in tables:
            pk_col = 'log_id' if table == 'user_input_logs' else 'id'
            try:
                cursor.execute(f"SELECT pg_get_serial_sequence('\"{table}\"', '{pk_col}')")
                seq = cursor.fetchone()[0]
                
                cursor.execute(f"SELECT last_value FROM {seq}")
                last_val = cursor.fetchone()[0]
                
                cursor.execute(f"SELECT MAX({pk_col}) FROM {table}")
                max_val = cursor.fetchone()[0] or 0
                
                results.append({
                    'table': table,
                    'seq': seq,
                    'last_val': last_val,
                    'max_val': max_val,
                    'synced': last_val > max_val
                })
            except Exception as e:
                results.append({'table': table, 'error': str(e)})
    
    for r in results:
        print(r)

if __name__ == "__main__":
    check_sequences()

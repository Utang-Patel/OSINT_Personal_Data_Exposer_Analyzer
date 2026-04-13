# scratch/test_wmn_speed.py
import time
import json
import os
import sys

# Add parent dir to path to import services
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from services.wmn_service import search_wmn

def test_speed(username):
    print(f"--- Starting WMN Speed Test for '{username}' ---")
    start_time = time.time()
    
    results = search_wmn(username)
    
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"\nScan completed in {duration:.2f} seconds.")
    print(f"Found {len(results)} accounts.")
    
    for r in results[:10]:
        print(f" [+] {r['name']}: {r['url']}")
    
    if len(results) > 10:
        print(f" ... and {len(results) - 10} more.")

if __name__ == "__main__":
    test_speed("aaryan.1901")

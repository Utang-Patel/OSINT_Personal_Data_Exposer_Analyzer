import requests

emails = ['nchauhan1901@gmail.com', 'aryanchauhan1981@gmail.com']

for email in emails:
    print(f"\n=== Testing: {email} ===")
    try:
        resp = requests.post(
            'http://127.0.0.1:8000/api/v1/osint/holehe/',
            json={'email': email},
            headers={'Accept': 'application/json'},
            timeout=60
        )
        data = resp.json()
        results = data.get('results', [])
        registered = [r for r in results if r.get('registered') == True]
        print(f"Status: {resp.status_code}")
        print(f"Total checked: {len(results)}")
        print(f"Registered: {len(registered)}")
        for r in registered:
            print(f"  -> {r['name']} ({r.get('domain', '')})")
    except Exception as e:
        print(f"Error: {e}")

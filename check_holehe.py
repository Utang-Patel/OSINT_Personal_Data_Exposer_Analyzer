import requests, json

resp = requests.post(
    'http://127.0.0.1:8000/api/v1/osint/holehe/',
    json={'email': 'aryanchauhan1981@gmail.com'},
    headers={'Accept': 'application/json'}
)
data = resp.json()
results = data.get('results', [])
registered = [r for r in results if r.get('registered') == True]
rate_limited = [r for r in results if r.get('rate_limit') == True]
print('Total:', len(results))
print('Registered (registered=True):', len(registered))
print('Rate limited:', len(rate_limited))
print()
print('=== REGISTERED platforms ===')
for r in registered:
    print('  ', r['name'], '-', r['domain'], '- rate_limit=', r['rate_limit'])

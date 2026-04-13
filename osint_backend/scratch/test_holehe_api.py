import requests
import json

def test_holehe_api(email):
    url = "http://127.0.0.1:8000/api/v1/osint/holehe/"
    headers = {"Content-Type": "application/json"}
    payload = {"email": email}
    
    print(f"Testing API POST {url} for {email}...")
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=120)
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            results = data.get("results", [])
            found = [r for r in results if r.get("registered")]
            print(f"Success! Found {len(found)} registrations.")
            for f in found:
                print(f" - {f.get('name')}: {f.get('url')}")
        else:
            print(f"Error {response.status_code}: {response.text[:500]}")
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_holehe_api("aryanchauhan1981@gmail.com")

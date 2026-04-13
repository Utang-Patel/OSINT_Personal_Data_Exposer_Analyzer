import os
import sys
import requests
import logging
import urllib3
import urllib.parse
from bs4 import BeautifulSoup
import phonenumbers
from phonenumbers import geocoder, carrier, timezone
from concurrent.futures import ThreadPoolExecutor
# Suppress insecure request warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logger = logging.getLogger(__name__)


import trio
import httpx

def search_username(username: str) -> list:
    """
    Mr.Holmes-style username search using multiple scrapers in parallel via Trio.
    Returns a list of profile URLs.
    """
    platforms = []
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                      '(KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
    }

    async def check_github(client):
        try:
            r = await client.get(f"https://api.github.com/search/users?q={username}+in:login", timeout=5)
            if r.status_code == 200:
                for i in r.json().get("items", [])[:5]:
                    if username.lower() in i.get("login", "").lower():
                        platforms.append(i.get("html_url"))
        except Exception: pass

    async def check_instagram(client):
        try:
            r = await client.get(f"https://www.picuki.com/search/{username}", timeout=5)
            if r.status_code == 200:
                soup = BeautifulSoup(r.content, features="html.parser")
                for user in soup.find_all("div", class_="profile-result")[:3]:
                    d = user.find("div", class_="result-username")
                    if d:
                        u = d.text.replace("@", "").strip()
                        if username.lower() in u.lower():
                            platforms.append(f"https://instagram.com/{u}")
        except Exception: pass

    async def check_tiktok(client):
        try:
            r = await client.get(f"https://urlebird.com/search/?q={username}", timeout=5)
            if r.status_code == 200:
                soup = BeautifulSoup(r.content, features="html.parser")
                for user in soup.find_all("div", class_="info")[:3]:
                    a = user.find("a", class_="uri")
                    if a:
                        u = a.text.replace("@", "").strip()
                        if username.lower() in u.lower():
                            platforms.append(f"https://tiktok.com/@{u}")
        except Exception: pass

    async def check_steam(client):
        try:
            url = f"https://steamcommunity.com/id/{username}"
            r = await client.get(url, timeout=5)
            if r.status_code == 200 and "The specified profile could not be found" not in r.text:
                platforms.append(url)
        except Exception: pass

    async def check_snapchat(client):
        try:
            url = f"https://www.snapchat.com/add/{username}"
            r = await client.get(url, timeout=5)
            if r.status_code == 200 and "Add on Snapchat" in r.text:
                platforms.append(url)
        except Exception: pass

    async def check_reddit(client):
        try:
            url = f"https://www.reddit.com/user/{username}/about.json"
            r = await client.get(url, timeout=5)
            if r.status_code == 200:
                platforms.append(f"https://www.reddit.com/user/{username}")
        except Exception: pass

    async def check_pinterest(client):
        try:
            url = f"https://www.pinterest.com/{username}/"
            r = await client.get(url, timeout=5)
            if r.status_code == 200 and ("pinterest.com/pin/" in r.text.lower() or "User" in r.text):
                if "Not Found" not in r.text:
                    platforms.append(url)
        except Exception: pass

    async def check_linktree(client):
        try:
            url = f"https://linktr.ee/{username}"
            r = await client.get(url, timeout=5)
            if r.status_code == 200 and "@" + username in r.text:
                platforms.append(url)
        except Exception: pass

    async def _run_all():
        async with httpx.AsyncClient(headers=headers, follow_redirects=True, verify=False) as client:
            async with trio.open_nursery() as nursery:
                nursery.start_soon(check_github, client)
                nursery.start_soon(check_instagram, client)
                nursery.start_soon(check_tiktok, client)
                nursery.start_soon(check_steam, client)
                nursery.start_soon(check_snapchat, client)
                nursery.start_soon(check_reddit, client)
                nursery.start_soon(check_pinterest, client)
                nursery.start_soon(check_linktree, client)

    try:
        trio.run(_run_all)
    except Exception as e:
        logger.error(f"Mr.Holmes scan failed: {e}")

    return list(set(filter(None, platforms)))


def search_phone(phone_number: str) -> dict:
    """
    Analyzes a phone number using phonenumbers + OSINT lookups.
    """
    results = {
        'phone': phone_number, 'valid': False,
        'international_format': '', 'local_format': '',
        'country_code': '', 'country': '', 'location': '',
        'carrier': '', 'timezones': '', 'latitude': '',
        'longitude': '', 'google_maps_link': '',
        'platforms': [], 'e164_format': '', 'line_type': 'Unknown'
    }
    try:
        clean_num = phone_number.strip()
        if not clean_num.startswith('+'):
            clean_num = '+' + clean_num
        parsed = phonenumbers.parse(clean_num, None)
        if phonenumbers.is_valid_number(parsed):
            results['valid'] = True
            results['international_format'] = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.INTERNATIONAL)
            results['local_format'] = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.NATIONAL)
            results['e164_format'] = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
            results['country_code'] = str(parsed.country_code)
            results['country'] = geocoder.country_name_for_number(parsed, "en")
            results['location'] = geocoder.description_for_number(parsed, "en")
            results['carrier'] = carrier.name_for_number(parsed, "en")
            tz_list = list(timezone.time_zones_for_number(parsed))
            results['timezones'] = ", ".join(tz_list) if tz_list else ""
            results['line_type'] = {
                0: "Fixed Line", 1: "Mobile", 2: "Fixed or Mobile",
                3: "Toll Free", 4: "Premium Rate", 5: "Shared Cost",
                6: "VoIP", 7: "Personal Number", 8: "Pager",
                9: "Universal Access", 10: "Voice Mail"
            }.get(phonenumbers.number_type(parsed), "Unknown")

            if results['location']:
                try:
                    geo_url = (f"https://nominatim.openstreetmap.org/search"
                               f"?q={urllib.parse.quote(results['location'])}&format=json&limit=1")
                    geo_r = requests.get(geo_url, headers={'User-Agent': 'OSINT/1.0'}, timeout=5)
                    if geo_r.status_code == 200 and geo_r.json():
                        d = geo_r.json()[0]
                        results['latitude'] = d.get('lat')
                        results['longitude'] = d.get('lon')
                        results['google_maps_link'] = (
                            f"https://www.google.com/maps/place/{d.get('lat')},{d.get('lon')}")
                except Exception: pass

            sn = results['e164_format'].replace("+", "")
            for url in [f"https://spamcalls.net/en/number/{sn}", f"https://free-lookup.net/{sn}"]:
                try:
                    if requests.head(url, timeout=3).status_code == 200:
                        results['platforms'].append(url)
                except Exception: pass

    except Exception as e:
        logger.error(f"Phone search error: {e}")
    return results


def search_email(email: str) -> list:
    """
    Search for email registrations across 120+ services using Holehe.
    Uses the cloned holehe source from tools/holehe (megadose/holehe).
    Runs with trio exactly as holehe's own maincore does.
    Returns all results sorted by name.
    """
    # Ensure the cloned holehe tool is on the path
    holehe_tool_path = os.path.normpath(
        os.path.join(os.path.dirname(__file__), "..", "tools", "holehe")
    )
    if holehe_tool_path not in sys.path:
        sys.path.insert(0, holehe_tool_path)

    import trio  # type: ignore
    import httpx  # type: ignore
    import holehe.core as holehe_core  # type: ignore

    modules = holehe_core.import_submodules("holehe.modules")
    websites = holehe_core.get_functions(modules)
    out = []

    async def _run_all():
        client = httpx.AsyncClient(timeout=15)
        try:
            async with trio.open_nursery() as nursery:
                for website in websites:
                    nursery.start_soon(holehe_core.launch_module, website, email, client, out)
        finally:
            await client.aclose()

    trio.run(_run_all)

    out = sorted(out, key=lambda i: i.get('name', ''))

    return [
        {
            "name": entry.get("name", ""),
            "domain": entry.get("domain", ""),
            "url": entry.get("url") or (f"https://{entry.get('domain')}" if entry.get("domain") else None),
            "registered": entry.get("exists", False),
            "rate_limit": entry.get("rateLimit", False),
            "error": entry.get("error", False),
            "email_recovery": entry.get("emailrecovery"),
            "phone_number": entry.get("phoneNumber"),
            "others": entry.get("others"),
        }
        for entry in out
    ]

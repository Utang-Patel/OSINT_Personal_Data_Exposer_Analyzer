# services/wmn_service.py
# -----------------------------------------------------------------------
# WhatsMyName username enumeration service.
# Uses trio + httpx for asynchronous, high-performance scanning.
# -----------------------------------------------------------------------

import json
import os
import random
import logging
import urllib3
import trio
import httpx

# Suppress insecure request warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logger = logging.getLogger("checker")

# Path to the WMN dataset
_WMN_DATA_PATH = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "tools", "whatsmyname", "wmn-data.json")
)
if not os.path.exists(_WMN_DATA_PATH):
    _WMN_DATA_PATH = os.path.normpath(
        os.path.join(os.path.dirname(__file__), "..", "wmn-data.json")
    )

_USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0",
]

_TIMEOUT = 10.0
_MAX_CONCURRENT = 100  # High concurrency with Trio


def _load_sites() -> list:
    try:
        with open(_WMN_DATA_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("sites", [])
    except Exception as exc:
        logger.error("WMN: failed to load wmn-data.json: %s", exc)
        return []


async def _check_site_async(site: dict, username: str, client: httpx.AsyncClient, semaphore: trio.Semaphore, results: list):
    uri_template: str = site.get("uri_check", "")
    if not uri_template or "{account}" not in uri_template:
        return

    url = uri_template.replace("{account}", username)
    expected_code: int = int(site.get("e_code", 200))
    expected_string: str = site.get("e_string", "")
    miss_string: str = site.get("m_string", "")

    headers = {
        "User-Agent": random.choice(_USER_AGENTS),
        "Accept": "*/*",
    }

    async with semaphore:
        try:
            method = "POST" if "post_body" in site else "GET"
            data = site.get("post_body", "").replace("{account}", username) if method == "POST" else None
            
            # Merge custom headers if present
            request_headers = headers.copy()
            if "headers" in site:
                custom_headers = site["headers"]
                if isinstance(custom_headers, dict):
                    request_headers.update(custom_headers)
            
            response = await client.request(
                method, url, 
                content=data, 
                headers=request_headers, 
                timeout=_TIMEOUT, 
                follow_redirects=True
            )
            
            # Code match
            code_match = response.status_code == expected_code
            
            # String matching (case insensitive if possible)
            body = response.text
            string_match = (not expected_string) or (expected_string.lower() in body.lower())
            not_miss = (not miss_string) or (miss_string.lower() not in body.lower())

            if code_match and string_match and not_miss:
                results.append({
                    "name": site.get("name", ""),
                    "url": url,
                    "category": site.get("cat", "misc"),
                    "found": True,
                })
        except (httpx.RequestError, trio.TooSlowError):
            pass
        except Exception as e:
            logger.debug("WMN: error checking %s: %s", url, e)


def search_wmn(username: str) -> list[dict]:
    """
    Run a full WhatsMyName scan for [username].
    Synchronous wrapper for internal async execution.
    """
    sites = _load_sites()
    if not sites:
        return []

    found = []
    logger.info("WMN: scanning %d sites for '%s' using Trio", len(sites), username)

    async def _run_all():
        semaphore = trio.Semaphore(_MAX_CONCURRENT)
        async with httpx.AsyncClient(verify=False, timeout=_TIMEOUT) as client:
            async with trio.open_nursery() as nursery:
                for site in sites:
                    nursery.start_soon(_check_site_async, site, username, client, semaphore, found)

    try:
        trio.run(_run_all)
    except Exception as e:
        logger.error("WMN: Trio execution failed: %s", e)

    logger.info("WMN: found %d results for '%s'", len(found), username)
    return sorted(found, key=lambda x: x['name'])

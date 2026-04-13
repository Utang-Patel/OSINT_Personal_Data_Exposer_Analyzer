import os
import sys

# Add holehe tool path
holehe_tool_path = os.path.normpath(os.path.join(os.getcwd(), 'osint_backend', 'tools', 'holehe'))
if holehe_tool_path not in sys.path:
    sys.path.insert(0, holehe_tool_path)

import trio
import httpx
import holehe.core as holehe_core

def search_email_debug(email: str):
    modules = holehe_core.import_submodules("holehe.modules")
    websites = holehe_core.get_functions(modules)
    out = []

    async def _run_all():
        async with httpx.AsyncClient(timeout=15) as client:
            async with trio.open_nursery() as nursery:
                for website in websites:
                    nursery.start_soon(holehe_core.launch_module, website, email, client, out)

    try:
        trio.run(_run_all)
        print(f"Total results: {len(out)}")
        found = [r for r in out if r.get("exists")]
        print(f"Registered on: {len(found)} sites")
        for f in found:
            print(f"- {f.get('name')} ({f.get('domain')})")
    except Exception as e:
        print(f"CRASH: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_email = "aryanchauhan1981@gmail.com"
    print(f"Testing holehe for {test_email}...")
    search_email_debug(test_email)

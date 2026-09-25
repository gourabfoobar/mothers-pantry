"""Local, read-only Swiggy Instamart bridge. Python 3.11+, no packages."""
from __future__ import annotations

import base64
import difflib
import hashlib
import json
import os
import re
import secrets
import threading
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("PANTRY_HOST", "127.0.0.1")
PORT = int(os.environ.get("PORT", os.environ.get("PANTRY_PORT", "8765")))
BASE = os.environ.get("SWIGGY_BASE_URL", "https://mcp-staging.swiggy.com").rstrip("/")
MODE = os.environ.get("PANTRY_PROVIDER", "demo")
PUBLIC_URL = os.environ.get("PANTRY_PUBLIC_URL", os.environ.get("RENDER_EXTERNAL_URL", "")).rstrip("/")
if PUBLIC_URL:
    origin = urllib.parse.urlparse(PUBLIC_URL)
    if (origin.scheme != "https" or not origin.hostname or origin.username or origin.password
            or origin.path or origin.params or origin.query or origin.fragment):
        raise ValueError("PANTRY_PUBLIC_URL must be an HTTPS origin without a path")
REDIRECT = f"{PUBLIC_URL}/oauth/callback" if PUBLIC_URL else f"http://localhost:{PORT}/oauth/callback"
ALIASES = {
    "aloo": "potatoes", "alu": "potatoes", "peyaj": "onions",
    "peyaz": "onions", "pyaz": "onions", "pyaaz": "onions",
    "dim": "eggs", "anda": "eggs", "ande": "eggs",
    "doodh": "milk", "dudh": "milk", "atta": "wheat flour",
    "chawal": "rice", "chaal": "rice", "kela": "bananas",
    "kola": "bananas", "tamatar": "tomatoes",
}
DEMO = [
    ("potato1", "Potatoes", 1000, "grams", "1 kg", 45, "🥔"),
    ("onion1", "Onions", 1000, "grams", "1 kg", 52, "🧅"),
    ("tomato500", "Tomatoes", 500, "grams", "500 g", 30, "🍅"),
    ("rice1", "Rice", 1000, "grams", "1 kg", 95, "🍚"),
    ("atta2", "Wheat flour", 2000, "grams", "2 kg", 125, "🌾"),
    ("milk500", "Milk", 500, "millilitres", "500 ml", 32, "🥛"),
    ("eggs6", "Eggs", 6, "pieces", "6 pieces", 65, "🥚"),
    ("banana6", "Bananas", 6, "pieces", "6 pieces", 48, "🍌"),
]
state = {"token": None, "expires": 0, "client_id": None, "verifier": None, "csrf": None}
lock = threading.Lock()


class BridgeError(Exception):
    pass


def request_json(url: str, body: dict | None = None, headers: dict | None = None) -> tuple[dict, dict]:
    payload = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=payload, headers={
        "Accept": "application/json, text/event-stream",
        **({"Content-Type": "application/json"} if body is not None else {}),
        **(headers or {}),
    })
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            raw = response.read(2_000_000).decode()
            response_headers = dict(response.headers)
    except urllib.error.HTTPError as error:
        raise BridgeError(f"Provider returned HTTP {error.code}") from error
    except urllib.error.URLError as error:
        raise BridgeError(f"Provider connection failed: {error.reason}") from error
    if not raw.strip():
        return {}, response_headers
    if raw.lstrip().startswith("data:") or "\ndata:" in raw:
        events = [line[5:].strip() for line in raw.splitlines() if line.startswith("data:")]
        if not events:
            raise BridgeError("Provider returned an empty event stream")
        raw = events[-1]
    try:
        return json.loads(raw), response_headers
    except json.JSONDecodeError as error:
        raise BridgeError("Provider returned invalid JSON") from error


def connected() -> bool:
    import time
    return bool(state["token"]) and state["expires"] > time.time() + 60


def mcp_call(name: str, arguments: dict) -> dict:
    if not connected():
        raise BridgeError("Swiggy sign-in is required")
    headers = {"Authorization": f"Bearer {state['token']}"}
    session_id = None
    protocol_version = "2025-06-18"

    def post(payload: dict) -> dict:
        nonlocal session_id
        extra = dict(headers)
        if session_id:
            extra["Mcp-Session-Id"] = session_id
        if payload.get("method") != "initialize":
            extra["MCP-Protocol-Version"] = protocol_version
        result, response_headers = request_json(BASE + "/im", payload, extra)
        session_id = response_headers.get("Mcp-Session-Id", session_id)
        return result

    with lock:
        init = post({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                     "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                                "clientInfo": {"name": "Pantry", "version": "0.1.0"}}})
        if "error" in init:
            raise BridgeError("Provider rejected MCP initialization")
        protocol_version = init.get("result", {}).get("protocolVersion", protocol_version)
        post({"jsonrpc": "2.0", "method": "notifications/initialized"})
        result = post({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                       "params": {"name": name, "arguments": arguments}})
    if "error" in result:
        raise BridgeError(f"Provider rejected {name}")
    tool = result.get("result", {})
    if tool.get("isError"):
        raise BridgeError(f"Provider tool {name} failed")
    for part in tool.get("content", []):
        if part.get("type") == "text":
            try:
                envelope = json.loads(part["text"])
                if not envelope.get("success", False):
                    raise BridgeError(envelope.get("error", {}).get("message", f"{name} failed"))
                return envelope.get("data", {})
            except json.JSONDecodeError:
                continue
    if isinstance(tool.get("structuredContent"), dict):
        content = tool["structuredContent"]
        if not content.get("success", False):
            raise BridgeError(f"Provider tool {name} failed")
        return content.get("data", {})
    raise BridgeError(f"Provider returned no usable {name} data")


def addresses() -> list[dict]:
    if MODE == "demo":
        return [{"id": "demo-home", "addressLine": "Demo address"}]
    data = mcp_call("get_addresses", {})
    found = data.get("addresses")
    if not isinstance(found, list):
        raise BridgeError("Provider returned no address list")
    return found


def size(description: str) -> tuple[int, str] | None:
    match = re.search(r"(\d+(?:\.\d+)?)\s*(kg|g|gm|l|ml|pieces?|pcs?|units?)\b",
                      description.lower())
    if not match:
        return None
    number, unit = float(match.group(1)), match.group(2)
    if unit == "kg":
        return round(number * 1000), "grams"
    if unit in ("g", "gm"):
        return round(number), "grams"
    if unit == "l":
        return round(number * 1000), "millilitres"
    if unit == "ml":
        return round(number), "millilitres"
    return round(number), "pieces"


def products_for(query: str, address_id: str) -> list[dict]:
    canonical = ALIASES.get(query.lower().strip(), query.lower().strip())
    if MODE == "demo":
        return [
            {"id": row[0], "name": row[1], "aliases": [query], "amount": row[2],
             "unit": row[3], "packLabel": row[4], "price": row[5], "symbol": row[6],
             "requiresNameApproval": True}
            for row in DEMO if canonical in row[1].lower() or row[1].lower() in canonical
        ]
    data = mcp_call("search_products", {"addressId": address_id, "query": canonical})
    available = [item for item in data.get("products", [])
                 if item.get("inStock") and item.get("isAvail")]
    if not available:
        return []
    # Choose the closest returned name before comparing pack sizes. The app
    # still requires approval for every live suggestion.
    def name_score(item: dict) -> float:
        name = (item.get("displayName") or "").lower()
        if canonical in name:
            return 1.0
        return difflib.SequenceMatcher(None, canonical, name).ratio()

    family = max(available, key=name_score)
    output = []
    for variant in family.get("variations", []):
        if not variant.get("isInStockAndAvailable"):
            continue
        parsed = size(variant.get("quantityDescription", ""))
        if not parsed or not variant.get("spinId") or not variant.get("skuId"):
            continue
        amount, unit = parsed
        output.append({
            "id": variant["spinId"], "skuId": variant["skuId"],
            "name": variant.get("displayName") or family.get("displayName") or canonical,
            "aliases": [query], "amount": amount, "unit": unit,
            "packLabel": variant["quantityDescription"],
            "price": round(variant.get("price", {}).get("offerPrice", 0)),
            "symbol": "🛒", "requiresNameApproval": True,
        })
    return output


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        # Avoid logging auth codes, tokens, or pasted message text.
        pass

    def send_json(self, code: int, body: dict) -> None:
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def redirect(self, url: str) -> None:
        self.send_response(302)
        self.send_header("Location", url)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def do_GET(self) -> None:
        path = urllib.parse.urlparse(self.path)
        try:
            if path.path == "/status":
                self.send_json(200, {"provider": MODE, "connected": MODE == "demo" or connected()})
            elif path.path == "/addresses":
                self.send_json(200, {"addresses": addresses()})
            elif path.path == "/connect":
                if MODE == "demo":
                    self.send_json(200, {"message": "Demo provider is active"})
                    return
                registration, _ = request_json(BASE + "/auth/register", {
                    "client_name": "Pantry local development",
                    "redirect_uris": [REDIRECT],
                    "grant_types": ["authorization_code"],
                    "response_types": ["code"],
                    "token_endpoint_auth_method": "none",
                })
                client_id = registration.get("client_id")
                if not client_id:
                    raise BridgeError("Provider did not return a client ID")
                verifier = secrets.token_urlsafe(48)
                challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
                csrf = secrets.token_urlsafe(32)
                state.update(client_id=client_id, verifier=verifier, csrf=csrf)
                parameters = {
                    "response_type": "code", "client_id": client_id, "redirect_uri": REDIRECT,
                    "code_challenge": challenge, "code_challenge_method": "S256",
                    "state": csrf, "scope": "mcp:tools",
                }
                self.redirect(BASE + "/auth/authorize?" + urllib.parse.urlencode(parameters))
            elif path.path == "/oauth/callback":
                params = urllib.parse.parse_qs(path.query)
                if not state["csrf"] or params.get("state", [None])[0] != state["csrf"]:
                    self.send_json(400, {"error": "OAuth state mismatch"})
                    return
                code = params.get("code", [None])[0]
                if not code:
                    self.send_json(400, {"error": "Authorization was not completed"})
                    return
                token, _ = request_json(BASE + "/auth/token", {
                    "grant_type": "authorization_code", "code": code,
                    "code_verifier": state["verifier"], "client_id": state["client_id"],
                    "redirect_uri": REDIRECT,
                })
                import time
                state.update(token=token["access_token"],
                             expires=time.time() + int(token["expires_in"]),
                             verifier=None, csrf=None)
                self.send_json(200, {"message": "Swiggy connected. Return to Pantry."})
            else:
                self.send_json(404, {"error": "Not found"})
        except (BridgeError, KeyError, ValueError) as error:
            self.send_json(502, {"error": str(error)})

    def do_POST(self) -> None:
        if self.path != "/catalog":
            self.send_json(404, {"error": "Not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 100_000:
                self.send_json(413, {"error": "Request too large"})
                return
            body = json.loads(self.rfile.read(length))
            address_id = body.get("addressId")
            requests = body.get("requests")
            valid_addresses = {item["id"] for item in addresses()}
            if address_id not in valid_addresses or not isinstance(requests, list) or len(requests) > 30:
                self.send_json(400, {"error": "Select a current saved address and up to 30 items"})
                return
            rows = []
            for item in requests:
                name = item.get("name", "")
                if not isinstance(name, str) or not 0 < len(name) <= 80:
                    self.send_json(400, {"error": "Invalid item name"})
                    return
                rows.append({"name": name, "products": products_for(name, address_id)})
            self.send_json(200, {"results": rows, "provider": MODE})
        except (BridgeError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
            self.send_json(502, {"error": str(error)})


if __name__ == "__main__":
    if PUBLIC_URL and MODE != "demo":
        raise SystemExit("Public Swiggy mode requires per-user authentication and token storage; run demo mode only")
    print(f"Pantry bridge: http://{HOST}:{PORT} ({MODE})")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()

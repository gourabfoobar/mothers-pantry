# Mother’s Pantry for iPhone

A SwiftUI app that turns a pasted WhatsApp grocery list into a reviewable Instamart shopping plan. It never places an order.

## Run locally

Open Pantry.xcodeproj in Xcode and run on an iPhone simulator (iOS 17+). Without a backend, the app uses its built-in sample catalog.

[Watch the demo](https://drive.google.com/file/d/1fyLpDA7YO2cYXIKv0MnsXEq9jJP98vHU/view).

For the local backend demo, start:

    python3 Backend/server.py

The bridge listens on 127.0.0.1:8765 and serves sample data by default. Restart Pantry or tap Refresh; it should show “Local demo bridge.” Paste one item per line, such as:

    aloo 1 kg
    peyaj 500 g
    dim 6
    atta 1 kg

The app sends item names to the local bridge for search. It shows the original request and suggested product with pack quantity. Translated names, unspecified units, and quantity differences require approval. Unknown items are flagged. The 500 g onion and 1 kg flour examples find packs containing twice the requested amount.

## Swiggy staging

Swiggy’s [developer quickstart](https://mcp.swiggy.com/builders/docs/start/developer/) and [Instamart reference](https://mcp.swiggy.com/builders/docs/reference/instamart/) describe the official provider connection. Once staging access is granted, run:

    PANTRY_PROVIDER=swiggy SWIGGY_BASE_URL=https://mcp-staging.swiggy.com python3 Backend/server.py

In the simulator, tap Connect Swiggy. The local bridge registers an OAuth client, opens Swiggy’s phone/OTP page, receives the PKCE callback, and holds the access token in memory. It fetches saved addresses, then searches Instamart variants for the selected address. Tokens and message text are not logged. Restarting the bridge clears the sign-in.

The bridge is bound to localhost and currently supports the iPhone simulator on the same Mac. A physical phone or production deployment needs an HTTPS backend URL, exact redirect URI allowlisting, per-user secure token storage, and deployment-specific network configuration. Swiggy reviews production access; apply through the [Builders Club access page](https://mcp.swiggy.com/builders/access/) with a demo video.

## Hosting setup

The Python bridge is deployed as a **demo-only** Render web service at https://mothers-pantry-bridge.onrender.com/status. Its reserved OAuth callback is https://mothers-pantry-bridge.onrender.com/oauth/callback. The service uses the private `gourabfoobar/mothers-pantry` GitHub repository, the free Python 3 instance in Singapore, and `/status` as the health check. The included `render.yaml` records the same configuration for future setup; this service was created through the Render dashboard.

The free instance is suitable for this access-application prototype and can sleep when idle. Upgrade the service before serving real users. The hosted bridge intentionally refuses live Swiggy mode: the local prototype holds one OAuth token in memory, so a public service first needs authenticated users and separate, persistent token storage. Keep `PANTRY_PROVIDER=demo` on Render until that work is complete. The iPhone app still points to the local bridge; hosting the demo callback does not connect it to live Swiggy.

## Current checkout boundary

The live path is read-only. Search prices are not a payable quote. Before enabling orders, implement selected-variant cart updates, re-read get_cart, show address, fees, stock and final total, and require another explicit approval before checkout. Handle ambiguous checkout errors by checking order history before retrying. No order or payment can be made with this build.

## Checks

    swiftc -module-cache-path /tmp/pantry-module-cache Sources/Models.swift Tests/main.swift -o /tmp/pantry-checks
    /tmp/pantry-checks
    python3 -m py_compile Backend/server.py

The app builds and launches with Xcode 27 on an iPhone 18 Pro simulator running iOS 27. The local bridge status and catalog endpoints were checked with the demo provider; live Swiggy staging calls remain unverified until access and sign-in are available.

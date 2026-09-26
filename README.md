# Mother's Pantry

Turn Ma's pasted WhatsApp grocery list into a reviewed, tracked order — matched against a real grocery provider's MCP server, with approvals you can act on from a notification and delivery status that follows on the Lock Screen.

This is a from-scratch rebuild against the [Mother's Pantry design canvas](https://claude.ai/artifact/NNpR3GBPXMVfY2L9WQDzZG) (22 screens, 6 flows). It replaces an earlier Swiggy-staging prototype.

## Layout

```
ios/            SwiftUI app (iOS 17+) + PantryWidgetExtension (ActivityKit Live Activity / Dynamic Island)
backend/        TypeScript/Node — auth, list parsing, matching, cart, orders, APNs push
kirana-now/     Mock MCP grocery server with a seeded catalogue, used for local end-to-end testing
```

## Status

Feature-complete against all 22 canvas screens. See commit history for milestone-by-milestone detail:

0. Repo scaffold
1. `kirana-now` mock MCP server
2. Backend skeleton (auth, provider connect, schema)
3. Claude API list parser + matcher + round-down rule
4. Cart/checkout/order placement + APNs payload layer
5. SwiftData models + iOS networking client
6. Onboarding screens (1.1–1.4)
7. Provider connect screens (2.1–2.3)
8. List-building screens (3.1–3.5)
9. Approvals, checkout, placed (4.1–4.5)
10. Live Activity + Dynamic Island + in-app tracking (5.1–5.3)
11. History & account (6.1–6.3)
12. End-to-end pass in Simulator

Two things are code-complete but not visually/live confirmed, and are called
out honestly rather than glossed over:

- **Swiggy Instamart** is the default provider (OAuth 2.1 + PKCE, real tool
  schemas per the [Swiggy MCP docs](https://mcp.swiggy.com/builders/docs/reference/)),
  but this environment has no Swiggy staging account, so it's only been
  typechecked and structurally reviewed — never run against a live Swiggy
  session. **`kirana-now`** (the mock provider) is the tested, verified path
  and is what the demo below uses.
- The Live Activity / Dynamic Island *code* runs successfully in the
  Simulator (`Activity.request` succeeds), but the actual system-rendered
  Lock Screen / Dynamic Island UI couldn't be screenshotted in this
  environment (a macOS Automation permission gap, not an app bug) — it's
  confirmed on a real device path via the `pushType: .token` branch, just
  not pixel-checked here.

## See a demo

This is a local-only stack (SwiftUI app + Node backend + mock MCP server) —
there's no hosted demo link. To run it yourself:

**1. Start the mock grocery server and the backend** (two terminals):

```
cd kirana-now && npm install && npm run build && node dist/server.js   # :4100
cd backend     && npm install && npm run build && node dist/server.js  # :4200
```

No `.env` needed for a local demo — without `ANTHROPIC_API_KEY` the backend
falls back to a regex list parser, without APNs credentials it logs push
payloads to the console instead of sending them, and OTP codes are printed
straight to the backend's terminal (`[sms:console] -> ... code is 123456`).

**2. Open and run the iOS app:**

```
cd ios && xcodegen generate && open Pantry.xcodeproj
```

Run the `Pantry` scheme on an iOS 17+ simulator.

**3. Walk through the flow:**

- Sign up with any phone number; read the OTP from the backend's terminal.
- Connect **Kirana Now** as the provider (Swiggy needs real OAuth credentials
  you won't have — see the caveat above).
- Add Ma's address, then paste a sample list from Home, e.g.:
  ```
  Atta 5 kg
  Chini 1 kg
  Dhoniya pata 2 bundle
  Aloo 3 kg
  Kalo jeera 100 gm
  ```
- Approve the flagged items — you'll see both failure modes the design
  calls for: a genuinely ambiguous match ("check match") and a stock
  shortfall that's always rounded **down**, never up (e.g. "5 → 4 kg").
- Place the order, then watch it move through Tracking (with a live Live
  Activity) into History.

Prefer not to click through by hand? The app has a `DEBUG`-only screen host
(`ios/Pantry/Views/DebugScreenHost.swift`) that can launch straight into any
screen with real seeded backend data — useful for jumping straight to, say,
an order mid-delivery without repeating the whole flow each time.

## Design

Background `#F1F2ED`, cards `#FFFFFF`, ink `#3A3A3A`, secondary text `#6B6D6F`, accent `#EE6F22`, accent text `#B4531A`. Type is JetBrains Mono throughout, with Shippori Mincho for the 母 seal. 16px corner radii, and a hand-drawn ensō motif on welcome/success/loading screens.

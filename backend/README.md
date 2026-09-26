# Pantry backend

TypeScript/Node service: phone+OTP auth, provider connect (MCP client to
`kirana-now`), and — from milestone 3 on — list parsing, matching, cart,
checkout, orders and APNs push.

## Run

```
cp .env.example .env
npm install
npm run dev          # http://localhost:4200, needs kirana-now running on :4100
```

`npm run smoke` drives a full signup → profile → connect-provider →
recipient/address flow against a running server (`devCode` is only returned
by `/auth/otp/request` outside `NODE_ENV=production`, so the smoke test never
has to read the console-stub SMS log).

## Auth

Phone + 6-digit OTP, 5 minute expiry, 5 attempts before lockout. `SmsProvider`
(`src/services/sms.ts`) is a small interface with a console-log stub for dev;
point `SMS_PROVIDER` at a real implementation once you have credentials.
`POST /auth/otp/verify` returns `isNewUser` — the iOS app uses that to decide
whether to continue to the "About you" screen or go straight Home.

## Providers

`GET /providers` lists Kirana Now, Bazaar Direct, FreshCart (available) and
Daily Basket (not available at this pincode), matching the canvas's picker.
Only `kirana-now` is backed by a live MCP connection (`src/mcp/kiranaClient.ts`)
today; connecting any other provider records a connection row but nothing
downstream talks to it yet.

## Data

SQLite via Node's built-in `node:sqlite` (`DatabaseSync`), schema in
`src/db/schema.sql`, applied on boot. (`better-sqlite3`'s prebuilt native
binding crashes under Node 24's GC/module-evaluation timing on this machine —
`node:sqlite` has the same `prepare/get/all/run` shape and needed no query
changes beyond typing `req.userId!` past `requireAuth`.)

## Lists, matching & approvals (milestone 3)

`POST /lists` parses pasted text with `ListParser` (`src/services/parser.ts`) —
`ClaudeListParser` when `ANTHROPIC_API_KEY` is set, otherwise a regex
`HeuristicListParser` so the whole flow works offline. `POST /lists/:id/match`
runs each parsed item through `src/services/matcher.ts`:

1. `search_products` on kirana-now, ranked by alias match.
2. A **tied top score** (e.g. "kalo jeera" matching both nigella seeds and
   black cumin equally) → `needs_match`, both candidates returned.
3. A **requested unit kirana-now can't map without guessing** (e.g. "2
   bundle") → confidence penalty → `needs_match`.
4. Either way, `update_cart_item` always runs for the best-guess candidate —
   **a rounded-down allocation always requires approval** (`needs_qty`),
   overriding an otherwise-confident match.

`POST /matches/:id/approve|reject` and `POST /qty/:id/approve|reject` resolve
an item (optionally switching to an alternate candidate); `GET
/lists/:id/review` returns the same shape the Review screen needs. Verified
against Ma's exact sample list (`npx tsx src/smoke-test-match.ts` once both
servers are running) — atta 5 kg asked → 4 kg / ₹236 via 2×2 kg, and the
"kalo jeera" ambiguity surfaces both candidates, matching the canvas exactly.
`npx tsx src/smoke-test-approve.ts` covers approving a rounded-down qty,
switching a match to an alternate candidate, and rejecting a line.

## Cart, checkout, orders & push (milestone 4)

- `GET /orders/cart/:listId` — the checkout payload; `ready` is only true once
  every non-rejected item is `approved` (canvas note 4: "Checkout unlocks
  once every item is approved or removed").
- `POST /orders/place/:listId` — 409s if anything is unresolved, otherwise
  calls kirana-now's `place_order` and creates the local `orders` row.
- `POST /orders/:id/activity-token` — the iOS app posts its Live Activity's
  push-to-update token here once it starts the Activity.
- `GET /orders`, `GET /orders/:id`, `POST /orders/:id/reorder` (re-runs
  matching against today's stock, sharing `src/services/listService.ts` with
  the initial `POST /lists/:id/match`).

`src/services/orderPoller.ts` polls kirana-now's `get_order_status` every
`ORDER_POLL_INTERVAL_MS` (default 5s) for every non-delivered order, records
new `order_events`, and pushes an ActivityKit update through
`src/services/apns.ts` whenever status changes — `end` on delivery, `update`
otherwise. `src/services/notifications.ts` fires one actionable notification
per item that needs a look right after matching, matching canvas 4.1's Lock
Screen (a separate card per approval, not one digest).

`apns.ts` is a real HTTP/2 client (ES256 provider-token auth, correct
`apns-push-type`/`apns-topic` headers for both `liveactivity` and `alert`)
that talks to Apple when `APNS_KEY_ID`/`APNS_TEAM_ID`/`APNS_KEY_PATH`/
`APNS_BUNDLE_ID` are set, and otherwise logs the payload — same pattern as
`SmsProvider` and `ListParser`.

`npx tsx src/smoke-test-order.ts` (with both servers running) drives a full
signup → connect → list → auto-match → cart-gate → place → poll-to-"packed"
run against the real kirana-now timer.

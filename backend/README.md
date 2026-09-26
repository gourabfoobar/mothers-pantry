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

SQLite via `better-sqlite3`, schema in `src/db/schema.sql`, applied on boot.

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

Tables for cart/checkout/orders already exist in the schema; the routes that
use them land in milestone 4.

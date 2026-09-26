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
Tables for lists/matching/cart/orders already exist in the schema; the
matching, cart, checkout and order routes that use them land in milestones 3–4.

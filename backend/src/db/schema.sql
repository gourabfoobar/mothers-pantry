-- Mother's Pantry backend schema (SQLite).
-- Milestone 2 wires up users/otp/recipients/addresses/provider_connections/devices.
-- Milestone 3-4 wire up the list/matching/cart/order tables below.

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone TEXT NOT NULL UNIQUE,
  name TEXT,
  email TEXT,
  notifications_enabled INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS otp_codes (
  phone TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS recipients (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  relation TEXT,
  phone TEXT,
  may_call INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS addresses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  recipient_id TEXT REFERENCES recipients(id),
  label TEXT NOT NULL,
  line1 TEXT NOT NULL,
  city TEXT,
  pincode TEXT,
  -- Cache of this address as created on the currently-connected provider
  -- (Swiggy's own addressId from create_address/get_addresses; irrelevant
  -- for kirana-now, which accepts our internal id directly).
  provider_id TEXT,
  provider_address_id TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS provider_connections (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  provider_id TEXT NOT NULL,
  access_token TEXT,
  expires_at TEXT,
  nearest_store_id TEXT,
  nearest_store_name TEXT,
  connected_at TEXT NOT NULL
);

-- In-flight Swiggy OAuth 2.1 + PKCE handshakes (RFC 7591 dynamic client
-- registration means there's no static client id to configure).
CREATE TABLE IF NOT EXISTS oauth_sessions (
  state TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  provider_id TEXT NOT NULL,
  code_verifier TEXT NOT NULL,
  redirect_uri TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | complete | failed
  error TEXT,
  created_at TEXT NOT NULL
);

-- The Dynamic Client Registration response, cached so we only register once
-- per provider per environment.
CREATE TABLE IF NOT EXISTS oauth_clients (
  provider_id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL,
  registered_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  push_token TEXT,
  activity_push_to_start_token TEXT,
  registered_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS grocery_lists (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  address_id TEXT NOT NULL REFERENCES addresses(id),
  raw_text TEXT NOT NULL,
  cart_id TEXT,
  greeting_count INTEGER NOT NULL DEFAULT 0,
  matched_at TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS list_lines (
  id TEXT PRIMARY KEY,
  list_id TEXT NOT NULL REFERENCES grocery_lists(id),
  raw_text TEXT NOT NULL,
  position INTEGER NOT NULL,
  is_greeting INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS match_candidates (
  id TEXT PRIMARY KEY,
  line_id TEXT NOT NULL REFERENCES list_lines(id),
  catalog_item_id TEXT NOT NULL,
  catalog_item_name TEXT NOT NULL,
  confidence REAL NOT NULL,
  reason TEXT,
  price REAL,
  rank INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS order_items (
  id TEXT PRIMARY KEY,
  list_id TEXT NOT NULL REFERENCES grocery_lists(id),
  line_id TEXT NOT NULL REFERENCES list_lines(id),
  catalog_item_id TEXT,
  catalog_item_name TEXT,
  requested_qty REAL NOT NULL,
  requested_unit TEXT NOT NULL,
  approved_qty REAL, -- the allocated/fulfilled quantity, set as soon as matching resolves a candidate; `status` tracks whether the user has actually approved it
  pack_description TEXT,
  line_total REAL,
  status TEXT NOT NULL DEFAULT 'needs_match',
  rounded_down INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  list_id TEXT REFERENCES grocery_lists(id),
  address_id TEXT NOT NULL REFERENCES addresses(id),
  provider_order_id TEXT,
  status TEXT NOT NULL DEFAULT 'placed',
  total REAL,
  courier_name TEXT,
  courier_distance_km REAL,
  activity_push_token TEXT,
  placed_at TEXT,
  eta_at TEXT
);

CREATE TABLE IF NOT EXISTS order_events (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id),
  type TEXT NOT NULL,
  label TEXT,
  at TEXT NOT NULL
);

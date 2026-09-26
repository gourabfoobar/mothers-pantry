import { randomBytes, createHash, randomUUID } from "node:crypto";
import { db } from "../db/index.js";

/**
 * OAuth 2.1 + PKCE against Swiggy's real MCP auth server, per
 * https://mcp.swiggy.com/builders/docs/start/authenticate.md. Defaults to
 * staging (seeded data, no real orders) — set SWIGGY_MCP_ORIGIN=
 * https://mcp.swiggy.com once you have production access.
 */
export const SWIGGY_ORIGIN = process.env.SWIGGY_MCP_ORIGIN ?? "https://mcp-staging.swiggy.com";
export const SWIGGY_REDIRECT_URI = process.env.SWIGGY_REDIRECT_URI ?? "http://localhost:4200/providers/swiggy/callback";

function base64url(buf: Buffer): string {
  return buf.toString("base64url");
}

/**
 * Dynamic Client Registration (RFC 7591) — Swiggy MCP has no static client
 * id to configure; every deployment registers itself once and caches the
 * result.
 */
export async function getOrRegisterClientId(): Promise<string> {
  const cached = db.prepare("SELECT client_id as clientId FROM oauth_clients WHERE provider_id = 'swiggy'").get() as
    | { clientId: string }
    | undefined;
  if (cached) return cached.clientId;

  const res = await fetch(`${SWIGGY_ORIGIN}/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      redirect_uris: [SWIGGY_REDIRECT_URI],
      client_name: "Mother's Pantry",
      grant_types: ["authorization_code"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
    }),
  });
  if (!res.ok) {
    throw new Error(`Swiggy dynamic client registration failed: HTTP ${res.status} ${await res.text()}`);
  }
  const body = (await res.json()) as { client_id: string };
  db.prepare("INSERT INTO oauth_clients (provider_id, client_id, registered_at) VALUES ('swiggy', ?, ?)").run(
    body.client_id,
    new Date().toISOString(),
  );
  return body.client_id;
}

export interface StartedAuth {
  authorizeUrl: string;
  state: string;
}

/** Begins the flow: generates PKCE, records the in-flight session, returns the URL to open in a browser. */
export async function startSwiggyAuth(userId: string, redirectUri: string = SWIGGY_REDIRECT_URI): Promise<StartedAuth> {
  const clientId = await getOrRegisterClientId();
  const codeVerifier = base64url(randomBytes(32));
  const codeChallenge = base64url(createHash("sha256").update(codeVerifier).digest());
  const state = randomUUID();

  db.prepare(
    `INSERT INTO oauth_sessions (state, user_id, provider_id, code_verifier, redirect_uri, status, created_at)
     VALUES (?, ?, 'swiggy', ?, ?, 'pending', ?)`,
  ).run(state, userId, codeVerifier, redirectUri, new Date().toISOString());

  const url = new URL(`${SWIGGY_ORIGIN}/auth/authorize`);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("code_challenge", codeChallenge);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("state", state);
  url.searchParams.set("scope", "mcp:tools");

  return { authorizeUrl: url.toString(), state };
}

export interface TokenResult {
  accessToken: string;
  expiresAt: string;
}

/** Completes the flow after Swiggy redirects back with `?code&state`. */
export async function completeSwiggyAuth(code: string, state: string): Promise<{ userId: string; token: TokenResult }> {
  const session = db
    .prepare("SELECT user_id as userId, code_verifier as codeVerifier, redirect_uri as redirectUri FROM oauth_sessions WHERE state = ? AND status = 'pending'")
    .get(state) as { userId: string; codeVerifier: string; redirectUri: string } | undefined;
  if (!session) throw new Error("Unknown or already-used OAuth state");

  const res = await fetch(`${SWIGGY_ORIGIN}/auth/token`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      grant_type: "authorization_code",
      code,
      code_verifier: session.codeVerifier,
      redirect_uri: session.redirectUri,
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    db.prepare("UPDATE oauth_sessions SET status = 'failed', error = ? WHERE state = ?").run(detail, state);
    throw new Error(`Swiggy token exchange failed: HTTP ${res.status} ${detail}`);
  }
  const body = (await res.json()) as { access_token: string; expires_in: number };
  const expiresAt = new Date(Date.now() + body.expires_in * 1000).toISOString();

  db.prepare("UPDATE oauth_sessions SET status = 'complete' WHERE state = ?").run(state);

  return { userId: session.userId, token: { accessToken: body.access_token, expiresAt } };
}

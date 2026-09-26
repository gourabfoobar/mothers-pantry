import { Router } from "express";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";
import { callKirana } from "../mcp/kiranaClient.js";
import { startSwiggyAuth, completeSwiggyAuth } from "../providers/swiggyOAuth.js";
import { DEFAULT_PROVIDER_ID } from "../providers/registry.js";

export const providersRouter = Router();

/**
 * Swiggy Instamart is the default, real provider
 * (https://mcp.swiggy.com/builders/docs/reference/instamart) — OAuth 2.1 +
 * PKCE against a live grocery catalogue. kirana-now stays available as an
 * always-on local/offline fallback that needs no account.
 */
const PROVIDERS = [
  {
    id: "swiggy",
    name: "Swiggy Instamart",
    subtitle: "Your real Swiggy account · sign in with phone + OTP",
    available: true,
  },
  {
    id: "kirana-now",
    name: "Kirana Now",
    subtitle: "Local demo catalogue · no account needed",
    available: true,
  },
];

providersRouter.get("/", (_req, res) => {
  res.json(PROVIDERS.map((p) => ({ ...p, isDefault: p.id === DEFAULT_PROVIDER_ID })));
});

/** kirana-now: no real account, just records the connection. */
providersRouter.post("/kirana-now/authorize", requireAuth, async (req: AuthedRequest, res) => {
  const store = await callKirana<{ storeId: string; name: string }>("get_store", {});
  if (!store.ok || !store.data) {
    res.status(502).json({ error: "provider_unreachable", detail: store.error });
    return;
  }

  const id = randomUUID();
  const connectedAt = new Date().toISOString();
  db.prepare(
    `INSERT INTO provider_connections (id, user_id, provider_id, access_token, nearest_store_id, nearest_store_name, connected_at)
     VALUES (?, ?, 'kirana-now', ?, ?, ?, ?)`,
  ).run(id, req.userId!, `demo-token-${id}`, store.data.storeId, store.data.name, connectedAt);

  res.json({
    id,
    providerId: "kirana-now",
    providerName: "Kirana Now",
    storeId: store.data.storeId,
    storeName: store.data.name,
    connectedAt,
  });
});

/** Swiggy: starts the real OAuth 2.1 + PKCE flow — the app opens `authorizeUrl` in a browser. */
providersRouter.post("/swiggy/authorize", requireAuth, async (req: AuthedRequest, res) => {
  try {
    const started = await startSwiggyAuth(req.userId!);
    res.json(started);
  } catch (err) {
    res.status(502).json({ error: "swiggy_unreachable", detail: err instanceof Error ? err.message : String(err) });
  }
});

const callbackSchema = z.object({ code: z.string(), state: z.string() });

/** Swiggy redirects here after phone+OTP consent on Swiggy's own page. */
providersRouter.get("/swiggy/callback", async (req, res) => {
  const parsed = callbackSchema.safeParse(req.query);
  if (!parsed.success) {
    res.status(400).send("Missing code or state");
    return;
  }
  try {
    const { userId, token } = await completeSwiggyAuth(parsed.data.code, parsed.data.state);
    const id = randomUUID();
    db.prepare(
      `INSERT INTO provider_connections (id, user_id, provider_id, access_token, expires_at, nearest_store_name, connected_at)
       VALUES (?, ?, 'swiggy', ?, ?, 'Swiggy Instamart', ?)`,
    ).run(id, userId, token.accessToken, token.expiresAt, new Date().toISOString());

    res.send(
      "<html><body style='font-family: -apple-system, sans-serif; text-align: center; padding: 60px 20px;'>" +
        "<h2>Swiggy connected</h2><p>You can go back to Mother's Pantry now.</p></body></html>",
    );
  } catch (err) {
    res.status(502).send(`Could not complete Swiggy sign-in: ${err instanceof Error ? err.message : String(err)}`);
  }
});

providersRouter.get("/connection", requireAuth, (req: AuthedRequest, res) => {
  const row = db
    .prepare("SELECT * FROM provider_connections WHERE user_id = ? ORDER BY connected_at DESC LIMIT 1")
    .get(req.userId!) as
    | {
        id: string;
        provider_id: string;
        nearest_store_id: string | null;
        nearest_store_name: string;
        connected_at: string;
      }
    | undefined;

  if (!row) {
    res.json(null);
    return;
  }
  const provider = PROVIDERS.find((p) => p.id === row.provider_id);
  res.json({
    id: row.id,
    providerId: row.provider_id,
    providerName: provider?.name ?? row.provider_id,
    storeId: row.nearest_store_id,
    storeName: row.nearest_store_name,
    connectedAt: row.connected_at,
  });
});

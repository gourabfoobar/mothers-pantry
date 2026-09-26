import { Router } from "express";
import { randomUUID } from "node:crypto";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";
import { callKirana } from "../mcp/kiranaClient.js";

export const providersRouter = Router();

/**
 * Only "kirana-now" is wired to a live MCP connection today. The others are
 * shown, matching the canvas's provider-picker, so the flow reads naturally,
 * but they don't yet have a server behind them.
 */
const PROVIDERS = [
  { id: "kirana-now", name: "Kirana Now", subtitle: "Delivers to 700029 · 15–30 min", available: true },
  { id: "bazaar-direct", name: "Bazaar Direct", subtitle: "Delivers to 700029 · same day", available: true },
  { id: "freshcart", name: "FreshCart", subtitle: "Delivers to 700029 · 30–45 min", available: true },
  { id: "daily-basket", name: "Daily Basket", subtitle: "Not available at this pincode", available: false },
];

providersRouter.get("/", (_req, res) => {
  res.json(PROVIDERS);
});

providersRouter.post("/:id/authorize", requireAuth, async (req: AuthedRequest, res) => {
  const providerId = req.params.id;
  const provider = PROVIDERS.find((p) => p.id === providerId);
  if (!provider || !provider.available) {
    res.status(400).json({ error: "provider_unavailable" });
    return;
  }

  let storeId = `${providerId}-store`;
  let storeName = provider.name;

  if (providerId === "kirana-now") {
    const store = await callKirana<{ storeId: string; name: string }>("get_store", {});
    if (!store.ok || !store.data) {
      res.status(502).json({ error: "provider_unreachable", detail: store.error });
      return;
    }
    storeId = store.data.storeId;
    storeName = store.data.name;
  }

  const id = randomUUID();
  const connectedAt = new Date().toISOString();
  db.prepare(
    `INSERT INTO provider_connections (id, user_id, provider_id, access_token, nearest_store_id, nearest_store_name, connected_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, req.userId, providerId, `demo-token-${id}`, storeId, storeName, connectedAt);

  res.json({ id, providerId, providerName: provider.name, storeId, storeName, connectedAt });
});

providersRouter.get("/connection", requireAuth, (req: AuthedRequest, res) => {
  const row = db
    .prepare("SELECT * FROM provider_connections WHERE user_id = ? ORDER BY connected_at DESC LIMIT 1")
    .get(req.userId) as
    | {
        id: string;
        provider_id: string;
        nearest_store_id: string;
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

import { Router } from "express";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";
import { createList, matchList } from "../services/listService.js";
import { activeProviderForUser } from "../providers/registry.js";
import { resolveProviderAddressId } from "../providers/addressResolution.js";
import type { ProviderContext } from "../providers/types.js";

export const ordersRouter = Router();

function loadList(listId: string, userId: string) {
  return db
    .prepare("SELECT id, cart_id as cartId, address_id as addressId, raw_text as rawText FROM grocery_lists WHERE id = ? AND user_id = ?")
    .get(listId, userId) as { id: string; cartId: string; addressId: string; rawText: string } | undefined;
}

function activeItems(listId: string) {
  return db
    .prepare(
      `SELECT id, catalog_item_name as name, requested_qty as requestedQty, requested_unit as requestedUnit,
              approved_qty as approvedQty, line_total as lineTotal, status, rounded_down as roundedDown
       FROM order_items WHERE list_id = ? AND status != 'rejected' ORDER BY position`,
    )
    .all(listId) as any[];
}

/** Checkout only unlocks once every non-rejected item is approved (canvas note 4). */
ordersRouter.get("/cart/:listId", requireAuth, (req: AuthedRequest, res) => {
  const list = loadList(req.params.listId, req.userId!);
  if (!list) {
    res.status(404).json({ error: "list_not_found" });
    return;
  }
  const items = activeItems(list.id);
  const unresolved = items.filter((i) => i.status !== "approved");
  const address = db.prepare("SELECT id, label, line1, city, pincode, recipient_id as recipientId FROM addresses WHERE id = ?").get(list.addressId);
  const total = items.reduce((sum, i) => sum + (i.lineTotal ?? 0), 0);

  res.json({
    ready: unresolved.length === 0 && items.length > 0,
    unresolvedCount: unresolved.length,
    address,
    items,
    itemTotal: total,
    delivery: 0,
    handling: 9,
    total: total + 9,
  });
});

ordersRouter.post("/place/:listId", requireAuth, async (req: AuthedRequest, res) => {
  const list = loadList(req.params.listId, req.userId!);
  if (!list) {
    res.status(404).json({ error: "list_not_found" });
    return;
  }
  const items = activeItems(list.id);
  const unresolved = items.filter((i) => i.status !== "approved");
  if (unresolved.length > 0 || items.length === 0) {
    res.status(409).json({ error: "not_ready", unresolvedCount: unresolved.length });
    return;
  }

  let order;
  try {
    const provider = activeProviderForUser(req.userId!);
    const providerAddressId = await resolveProviderAddressId(provider, req.userId!, list.addressId);
    const ctx: ProviderContext = { userId: req.userId!, providerAddressId };
    order = await provider.placeOrder(ctx, list.cartId);
  } catch (err) {
    res.status(502).json({ error: "provider_unreachable", detail: err instanceof Error ? err.message : String(err) });
    return;
  }

  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO orders (id, user_id, list_id, address_id, provider_order_id, status, total, courier_name,
       courier_distance_km, placed_at, eta_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    order.id,
    req.userId!,
    list.id,
    list.addressId,
    order.id,
    order.status,
    order.total,
    order.courierName ?? null,
    order.courierDistanceKm ?? null,
    now,
    order.etaAt ?? null,
  );
  for (const event of order.events) {
    db.prepare("INSERT INTO order_events (id, order_id, type, label, at) VALUES (?, ?, ?, ?, ?)").run(
      randomUUID(),
      order.id,
      event.status,
      event.label,
      event.at,
    );
  }

  res.status(201).json({ id: order.id, status: order.status, total: order.total, etaAt: order.etaAt });
});

const activityTokenSchema = z.object({ token: z.string().min(1) });

ordersRouter.post("/:id/activity-token", requireAuth, (req: AuthedRequest, res) => {
  const parsed = activityTokenSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request" });
    return;
  }
  const result = db
    .prepare("UPDATE orders SET activity_push_token = ? WHERE id = ? AND user_id = ?")
    .run(parsed.data.token, req.params.id, req.userId!);
  if (result.changes === 0) {
    res.status(404).json({ error: "order_not_found" });
    return;
  }
  res.json({ ok: true });
});

ordersRouter.get("/", requireAuth, (req: AuthedRequest, res) => {
  const rows = db
    .prepare(
      `SELECT o.id, o.status, o.total, o.placed_at as placedAt, o.eta_at as etaAt,
              a.label as addressLabel,
              (SELECT count(*) FROM order_items oi WHERE oi.list_id = o.list_id AND oi.status != 'rejected') as itemCount
       FROM orders o JOIN addresses a ON a.id = o.address_id
       WHERE o.user_id = ? ORDER BY o.placed_at DESC`,
    )
    .all(req.userId!);
  res.json(rows);
});

ordersRouter.get("/:id", requireAuth, (req: AuthedRequest, res) => {
  const order = db
    .prepare(
      `SELECT o.id, o.status, o.total, o.list_id as listId, o.courier_name as courierName,
              o.courier_distance_km as courierDistanceKm, o.placed_at as placedAt, o.eta_at as etaAt,
              a.label as addressLabel, a.line1 as addressLine1
       FROM orders o JOIN addresses a ON a.id = o.address_id
       WHERE o.id = ? AND o.user_id = ?`,
    )
    .get(req.params.id, req.userId!) as any;
  if (!order) {
    res.status(404).json({ error: "order_not_found" });
    return;
  }
  const events = db
    .prepare("SELECT type, label, at FROM order_events WHERE order_id = ? ORDER BY at")
    .all(order.id);
  const items = activeItems(order.listId);
  res.json({ ...order, events, items });
});

/** Re-runs matching against today's stock — approvals may be asked again (canvas note 6). */
ordersRouter.post("/:id/reorder", requireAuth, async (req: AuthedRequest, res) => {
  const order = db
    .prepare("SELECT list_id as listId FROM orders WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId!) as { listId: string } | undefined;
  if (!order) {
    res.status(404).json({ error: "order_not_found" });
    return;
  }
  const original = db
    .prepare("SELECT raw_text as rawText, address_id as addressId FROM grocery_lists WHERE id = ?")
    .get(order.listId) as { rawText: string; addressId: string };

  try {
    const created = await createList(req.userId!, original.addressId, original.rawText);
    await matchList(created.listId);
    res.status(201).json({ listId: created.listId });
  } catch (err) {
    res.status(502).json({ error: "provider_unreachable", detail: err instanceof Error ? err.message : String(err) });
  }
});

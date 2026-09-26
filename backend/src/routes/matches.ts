import { Router } from "express";
import { z } from "zod";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";
import { activeProviderForUser } from "../providers/registry.js";
import { resolveProviderAddressId } from "../providers/addressResolution.js";
import type { ProviderContext } from "../providers/types.js";

export const matchesRouter = Router();

function loadOrderItem(orderItemId: string, userId: string) {
  return db
    .prepare(
      `SELECT oi.id, oi.list_id as listId, gl.cart_id as cartId, gl.address_id as addressId,
              oi.requested_unit as requestedUnit
       FROM order_items oi
       JOIN grocery_lists gl ON gl.id = oi.list_id
       WHERE oi.id = ? AND gl.user_id = ?`,
    )
    .get(orderItemId, userId) as
    | { id: string; listId: string; cartId: string; addressId: string; requestedUnit: string }
    | undefined;
}

/** Approve a match by keeping the pre-selected candidate, or switching to an alternate. */
const approveMatchSchema = z.object({ catalogItemId: z.string().optional() });

matchesRouter.post("/:id/approve", requireAuth, async (req: AuthedRequest, res) => {
  const item = loadOrderItem(req.params.id, req.userId!);
  if (!item) {
    res.status(404).json({ error: "order_item_not_found" });
    return;
  }
  const parsed = approveMatchSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request" });
    return;
  }

  if (parsed.data.catalogItemId) {
    const candidate = db
      .prepare("SELECT catalog_item_name as name, price FROM match_candidates WHERE line_id = (SELECT line_id FROM order_items WHERE id = ?) AND catalog_item_id = ?")
      .get(item.id, parsed.data.catalogItemId) as { name: string; price: number } | undefined;
    if (!candidate) {
      res.status(404).json({ error: "candidate_not_found" });
      return;
    }
    const requestedQty = db.prepare("SELECT requested_qty as q FROM order_items WHERE id = ?").get(item.id) as { q: number };

    const provider = activeProviderForUser(req.userId!);
    const providerAddressId = await resolveProviderAddressId(provider, req.userId!, item.addressId);
    const ctx: ProviderContext = { userId: req.userId!, providerAddressId };
    const allocation = await provider.updateCartItem(ctx, item.cartId, parsed.data.catalogItemId, requestedQty.q, item.requestedUnit);

    db.prepare(
      `UPDATE order_items SET catalog_item_id = ?, catalog_item_name = ?, approved_qty = ?, pack_description = ?,
         line_total = ?, rounded_down = ?, status = ? WHERE id = ?`,
    ).run(
      parsed.data.catalogItemId,
      candidate.name,
      allocation.fulfilledQty,
      allocation.packDescription,
      allocation.lineTotal,
      allocation.roundedDown ? 1 : 0,
      allocation.roundedDown ? "needs_qty" : "approved",
      item.id,
    );
  } else {
    db.prepare("UPDATE order_items SET status = 'approved' WHERE id = ?").run(item.id);
  }

  res.json({ ok: true });
});

matchesRouter.post("/:id/reject", requireAuth, (req: AuthedRequest, res) => {
  const item = loadOrderItem(req.params.id, req.userId!);
  if (!item) {
    res.status(404).json({ error: "order_item_not_found" });
    return;
  }
  db.prepare("UPDATE order_items SET status = 'rejected' WHERE id = ?").run(item.id);
  res.json({ ok: true });
});

export const qtyRouter = Router();

qtyRouter.post("/:id/approve", requireAuth, (req: AuthedRequest, res) => {
  const item = loadOrderItem(req.params.id, req.userId!);
  if (!item) {
    res.status(404).json({ error: "order_item_not_found" });
    return;
  }
  // Accepting the rounded-down amount that's already allocated — Mother's
  // Pantry never offers "round up", so there's nothing else to negotiate.
  db.prepare("UPDATE order_items SET status = 'approved' WHERE id = ?").run(item.id);
  res.json({ ok: true });
});

qtyRouter.post("/:id/reject", requireAuth, (req: AuthedRequest, res) => {
  const item = loadOrderItem(req.params.id, req.userId!);
  if (!item) {
    res.status(404).json({ error: "order_item_not_found" });
    return;
  }
  db.prepare("UPDATE order_items SET status = 'rejected' WHERE id = ?").run(item.id);
  res.json({ ok: true });
});

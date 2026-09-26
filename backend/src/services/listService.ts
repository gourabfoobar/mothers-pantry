import { randomUUID } from "node:crypto";
import { db } from "../db/index.js";
import { listParser } from "./parser.js";
import { matchLine } from "./matcher.js";
import { activeProviderForUser } from "../providers/registry.js";
import { resolveProviderAddressId } from "../providers/addressResolution.js";
import type { ProviderContext } from "../providers/types.js";

export async function createList(userId: string, addressId: string, rawText: string) {
  const parsedList = await listParser.parse(rawText);
  const greetingCount = parsedList.totalLines - parsedList.items.length;

  const provider = activeProviderForUser(userId);
  const providerAddressId = await resolveProviderAddressId(provider, userId, addressId);
  const ctx: ProviderContext = { userId, providerAddressId };
  const { cartId } = await provider.ensureCart(ctx);

  const listId = randomUUID();
  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO grocery_lists (id, user_id, address_id, raw_text, cart_id, greeting_count, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(listId, userId, addressId, rawText, cartId, greetingCount, now);

  const insertLine = db.prepare("INSERT INTO list_lines (id, list_id, raw_text, position) VALUES (?, ?, ?, ?)");
  parsedList.items.forEach((item, i) => insertLine.run(randomUUID(), listId, item.rawPhrase, i));

  return { listId, itemCount: parsedList.items.length, greetingCount, providerId: provider.id };
}

export async function matchList(listId: string) {
  const list = db
    .prepare("SELECT id, user_id as userId, address_id as addressId, cart_id as cartId, raw_text as rawText FROM grocery_lists WHERE id = ?")
    .get(listId) as { id: string; userId: string; addressId: string; cartId: string; rawText: string } | undefined;
  if (!list) throw new Error("list_not_found");

  const provider = activeProviderForUser(list.userId);
  const providerAddressId = await resolveProviderAddressId(provider, list.userId, list.addressId);
  const ctx: ProviderContext = { userId: list.userId, providerAddressId };

  const reparsed = await listParser.parse(list.rawText);
  const lines = db
    .prepare("SELECT id, raw_text as rawText, position FROM list_lines WHERE list_id = ? ORDER BY position")
    .all(list.id) as { id: string; rawText: string; position: number }[];

  const insertCandidate = db.prepare(
    `INSERT INTO match_candidates (id, line_id, catalog_item_id, catalog_item_name, confidence, reason, price, rank)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  const insertOrderItem = db.prepare(
    `INSERT INTO order_items
       (id, list_id, line_id, catalog_item_id, catalog_item_name, requested_qty, requested_unit,
        approved_qty, pack_description, line_total, status, rounded_down, position)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );

  db.prepare("DELETE FROM match_candidates WHERE line_id IN (SELECT id FROM list_lines WHERE list_id = ?)").run(list.id);
  db.prepare("DELETE FROM order_items WHERE list_id = ?").run(list.id);

  for (const [i, item] of reparsed.items.entries()) {
    const line = lines[i];
    if (!line) continue;
    const result = await matchLine(provider, ctx, list.cartId, item);

    result.candidates.forEach((c, rank) => {
      insertCandidate.run(randomUUID(), line.id, c.catalogItemId, c.name, c.confidence, c.reason, c.price ?? null, rank);
    });

    insertOrderItem.run(
      randomUUID(),
      list.id,
      line.id,
      result.chosen?.catalogItemId ?? null,
      result.chosen?.name ?? null,
      item.requestedQty,
      item.requestedUnit,
      result.allocation?.fulfilledQty ?? null,
      result.allocation?.packDescription ?? null,
      result.allocation?.lineTotal ?? null,
      result.status === "matched" ? "approved" : result.status,
      result.allocation?.roundedDown ? 1 : 0,
      i,
    );
  }

  db.prepare("UPDATE grocery_lists SET matched_at = ? WHERE id = ?").run(new Date().toISOString(), list.id);
}

export function buildReview(listId: string) {
  const items = db
    .prepare(
      `SELECT oi.id, oi.line_id as lineId, ll.raw_text as rawText, oi.catalog_item_id as catalogItemId,
              oi.catalog_item_name as catalogItemName, oi.requested_qty as requestedQty,
              oi.requested_unit as requestedUnit, oi.approved_qty as approvedQty, oi.pack_description as packDescription,
              oi.line_total as lineTotal, oi.status, oi.rounded_down as roundedDown
       FROM order_items oi JOIN list_lines ll ON ll.id = oi.line_id
       WHERE oi.list_id = ? ORDER BY oi.position`,
    )
    .all(listId) as any[];

  const candidatesByLine = items.map((item) => ({
    ...item,
    roundedDown: Boolean(item.roundedDown),
    candidates: db
      .prepare(
        `SELECT catalog_item_id as catalogItemId, catalog_item_name as name, confidence, reason, price
         FROM match_candidates WHERE line_id = ? ORDER BY rank`,
      )
      .all(item.lineId),
  }));

  const matchedCount = candidatesByLine.filter((i) => i.status === "approved" && !i.roundedDown).length;
  const needsCount = candidatesByLine.filter((i) => i.status === "needs_match" || i.status === "needs_qty").length;
  const roundedDownCount = candidatesByLine.filter((i) => i.roundedDown).length;
  const total = candidatesByLine.reduce((sum, i) => sum + (i.lineTotal ?? 0), 0);

  return { itemCount: candidatesByLine.length, matchedCount, needsCount, roundedDownCount, total, items: candidatesByLine };
}

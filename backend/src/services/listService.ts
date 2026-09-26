import { randomUUID } from "node:crypto";
import { db } from "../db/index.js";
import { listParser } from "./parser.js";
import { matchLine } from "./matcher.js";
import { callKirana } from "../mcp/kiranaClient.js";

export async function createList(userId: string, addressId: string, rawText: string) {
  const parsedList = await listParser.parse(rawText);
  const greetingCount = parsedList.totalLines - parsedList.items.length;

  const cart = await callKirana<{ id: string }>("create_cart", {});
  if (!cart.ok || !cart.data) throw new Error(`provider_unreachable: ${cart.error}`);
  await callKirana("set_cart_address", { cartId: cart.data.id, addressId });

  const listId = randomUUID();
  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO grocery_lists (id, user_id, address_id, raw_text, cart_id, greeting_count, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(listId, userId, addressId, rawText, cart.data.id, greetingCount, now);

  const insertLine = db.prepare("INSERT INTO list_lines (id, list_id, raw_text, position) VALUES (?, ?, ?, ?)");
  parsedList.items.forEach((item, i) => insertLine.run(randomUUID(), listId, item.rawPhrase, i));

  return { listId, itemCount: parsedList.items.length, greetingCount };
}

export async function matchList(listId: string) {
  const list = db.prepare("SELECT id, cart_id as cartId, raw_text as rawText FROM grocery_lists WHERE id = ?").get(listId) as
    | { id: string; cartId: string; rawText: string }
    | undefined;
  if (!list) throw new Error("list_not_found");

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
        approved_qty, packs_json, line_total, status, rounded_down, position)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );

  db.prepare("DELETE FROM match_candidates WHERE line_id IN (SELECT id FROM list_lines WHERE list_id = ?)").run(list.id);
  db.prepare("DELETE FROM order_items WHERE list_id = ?").run(list.id);

  for (const [i, item] of reparsed.items.entries()) {
    const line = lines[i];
    if (!line) continue;
    const result = await matchLine(list.cartId, item);

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
      result.allocation ? JSON.stringify(result.allocation.packs) : null,
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
              oi.requested_unit as requestedUnit, oi.approved_qty as approvedQty, oi.packs_json as packsJson,
              oi.line_total as lineTotal, oi.status, oi.rounded_down as roundedDown
       FROM order_items oi JOIN list_lines ll ON ll.id = oi.line_id
       WHERE oi.list_id = ? ORDER BY oi.position`,
    )
    .all(listId) as any[];

  const withCandidates = items.map((item) => {
    const candidates = db
      .prepare(
        `SELECT catalog_item_id as catalogItemId, catalog_item_name as name, confidence, reason, price
         FROM match_candidates WHERE line_id = ? ORDER BY rank`,
      )
      .all(item.lineId);
    return { ...item, packs: item.packsJson ? JSON.parse(item.packsJson) : [], candidates };
  });

  const matchedCount = withCandidates.filter((i) => i.status === "approved" && !i.roundedDown).length;
  const needsCount = withCandidates.filter((i) => i.status === "needs_match" || i.status === "needs_qty").length;
  const roundedDownCount = withCandidates.filter((i) => i.roundedDown).length;
  const total = withCandidates.reduce((sum, i) => sum + (i.lineTotal ?? 0), 0);

  return { itemCount: withCandidates.length, matchedCount, needsCount, roundedDownCount, total, items: withCandidates };
}

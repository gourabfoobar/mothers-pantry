import { randomUUID } from "node:crypto";
import { CATALOG, CatalogItem, Pack, STORE_ID, STORE_NAME, findItem } from "./catalog.js";

// ---------- search ----------

export interface SearchHit {
  itemId: string;
  name: string;
  matchedAlias: string;
  score: number; // 0..1, higher is a closer name match
  packs: Pack[];
}

function normalize(text: string): string {
  return text.toLowerCase().trim().replace(/\s+/g, " ");
}

export function searchProducts(query: string, limit = 5): SearchHit[] {
  const q = normalize(query);
  const hits: SearchHit[] = [];
  for (const item of CATALOG) {
    let best: { alias: string; score: number } | null = null;
    for (const alias of [item.name, ...item.aliases]) {
      const a = normalize(alias);
      let score = 0;
      if (a === q) score = 1;
      else if (a.startsWith(q) || q.startsWith(a)) score = 0.85;
      else if (a.includes(q) || q.includes(a)) score = 0.65;
      if (score > 0 && (!best || score > best.score)) {
        best = { alias, score };
      }
    }
    if (best) {
      hits.push({ itemId: item.id, name: item.name, matchedAlias: best.alias, score: best.score, packs: item.packs });
    }
  }
  return hits.sort((a, b) => b.score - a.score).slice(0, limit);
}

export function getStock(itemId: string): CatalogItem | undefined {
  return findItem(itemId);
}

// ---------- pack allocation (the "always round down" rule) ----------

const UNIT_TO_BASE: Record<string, number> = { g: 1, kg: 1000, ml: 1, l: 1000, pcs: 1 };

export interface Allocation {
  itemId: string;
  requestedQty: number;
  requestedUnit: string;
  packs: { size: number; unit: string; count: number; price: number }[];
  fulfilledQty: number; // in the same unit family as requestedUnit's base
  fulfilledUnit: string;
  roundedDown: boolean;
  outOfStock: boolean;
  lineTotal: number;
}

/**
 * Greedily fills the request from the largest in-stock pack down, never
 * exceeding what was asked. Mother's Pantry never rounds up.
 */
export function allocatePacks(itemId: string, requestedQty: number, requestedUnit: string): Allocation | undefined {
  const item = findItem(itemId);
  if (!item) return undefined;

  let family: string;
  let requestedBase: number;
  if (UNIT_TO_BASE[requestedUnit] !== undefined) {
    family = requestedUnit;
    requestedBase = requestedQty * UNIT_TO_BASE[family];
  } else {
    // Unrecognized unit (e.g. Ma's "2 bundle") — treat the quantity as a
    // pack count against the item's own smallest pack, rather than
    // silently reinterpreting it as some other unit's number.
    const smallest = [...item.packs].sort(
      (a, b) => a.size * (UNIT_TO_BASE[a.unit] ?? 1) - b.size * (UNIT_TO_BASE[b.unit] ?? 1),
    )[0];
    family = smallest?.unit ?? "pcs";
    requestedBase = requestedQty * (smallest ? smallest.size * (UNIT_TO_BASE[smallest.unit] ?? 1) : 1);
  }

  const packsByBaseSizeDesc = [...item.packs]
    .filter((p) => UNIT_TO_BASE[p.unit] !== undefined)
    .sort((a, b) => b.size * UNIT_TO_BASE[b.unit] - a.size * UNIT_TO_BASE[a.unit]);

  let remaining = requestedBase;
  const chosen: { size: number; unit: string; count: number; price: number }[] = [];
  for (const pack of packsByBaseSizeDesc) {
    const packBase = pack.size * UNIT_TO_BASE[pack.unit];
    if (packBase <= 0) continue;
    const maxByRequest = Math.floor(remaining / packBase);
    const count = Math.max(0, Math.min(maxByRequest, pack.stockCount));
    if (count > 0) {
      chosen.push({ size: pack.size, unit: pack.unit, count, price: pack.price });
      remaining -= count * packBase;
    }
  }

  const fulfilledBase = requestedBase - remaining;
  const lineTotal = chosen.reduce((sum, p) => sum + p.count * p.price, 0);
  const base = UNIT_TO_BASE[family] ?? 1;

  return {
    itemId,
    requestedQty,
    requestedUnit: family,
    packs: chosen,
    fulfilledQty: fulfilledBase / base,
    fulfilledUnit: family,
    roundedDown: fulfilledBase < requestedBase,
    outOfStock: fulfilledBase === 0,
    lineTotal,
  };
}

// ---------- cart ----------

export interface CartLine {
  lineId: string;
  itemId: string;
  allocation: Allocation;
}

export interface Cart {
  id: string;
  addressId?: string;
  lines: CartLine[];
}

const carts = new Map<string, Cart>();

export function createCart(): Cart {
  const cart: Cart = { id: randomUUID(), lines: [] };
  carts.set(cart.id, cart);
  return cart;
}

export function getCart(cartId: string): Cart | undefined {
  return carts.get(cartId);
}

export function setCartAddress(cartId: string, addressId: string): Cart | undefined {
  const cart = carts.get(cartId);
  if (!cart) return undefined;
  cart.addressId = addressId;
  return cart;
}

export function upsertCartLine(cartId: string, itemId: string, requestedQty: number, requestedUnit: string): CartLine | undefined {
  const cart = carts.get(cartId);
  if (!cart) return undefined;
  const allocation = allocatePacks(itemId, requestedQty, requestedUnit);
  if (!allocation) return undefined;
  const existing = cart.lines.find((l) => l.itemId === itemId);
  const line: CartLine = existing ?? { lineId: randomUUID(), itemId, allocation };
  line.allocation = allocation;
  if (!existing) cart.lines.push(line);
  return line;
}

export function removeCartLine(cartId: string, lineId: string): boolean {
  const cart = carts.get(cartId);
  if (!cart) return false;
  const before = cart.lines.length;
  cart.lines = cart.lines.filter((l) => l.lineId !== lineId);
  return cart.lines.length < before;
}

export function cartTotal(cart: Cart): number {
  return cart.lines.reduce((sum, l) => sum + l.allocation.lineTotal, 0);
}

// ---------- orders ----------

export type OrderStatus = "placed" | "packed" | "on_the_way" | "delivered";

export interface OrderEvent {
  status: OrderStatus;
  label: string;
  at: string; // ISO timestamp
}

export interface Order {
  id: string;
  cartId: string;
  addressId?: string;
  lines: CartLine[];
  total: number;
  status: OrderStatus;
  events: OrderEvent[];
  courierName: string;
  courierDistanceKm: number;
  createdAt: string;
  etaAt: string;
}

const orders = new Map<string, Order>();

/** Real-world minutes compressed into seconds so the demo runs live. */
const STAGE_DELAY_MS = Number(process.env.KIRANA_STAGE_DELAY_MS ?? 15_000);

export function placeOrder(cartId: string): Order | undefined {
  const cart = carts.get(cartId);
  if (!cart || cart.lines.length === 0) return undefined;

  const now = new Date();
  const eta = new Date(now.getTime() + (STAGE_DELAY_MS * 3) + 60_000);
  const order: Order = {
    id: `MP-${Math.floor(1000 + Math.random() * 9000)}`,
    cartId,
    addressId: cart.addressId,
    lines: cart.lines,
    total: cartTotal(cart),
    status: "placed",
    events: [{ status: "placed", label: "Order placed", at: now.toISOString() }],
    courierName: "Ravi",
    courierDistanceKm: 4.2,
    createdAt: now.toISOString(),
    etaAt: eta.toISOString(),
  };
  orders.set(order.id, order);
  scheduleProgress(order.id);
  return order;
}

function scheduleProgress(orderId: string) {
  const stages: { status: OrderStatus; label: string }[] = [
    { status: "packed", label: `Packed at ${STORE_NAME}` },
    { status: "on_the_way", label: "Picked up by Ravi" },
    { status: "delivered", label: "Delivered" },
  ];
  stages.forEach((stage, i) => {
    setTimeout(() => {
      const order = orders.get(orderId);
      if (!order || order.status === "delivered") return;
      order.status = stage.status;
      order.events.push({ status: stage.status, label: stage.label, at: new Date().toISOString() });
      if (stage.status === "on_the_way") order.courierDistanceKm = 2.1;
      if (stage.status === "delivered") order.courierDistanceKm = 0;
    }, STAGE_DELAY_MS * (i + 1));
  });
}

export function getOrder(orderId: string): Order | undefined {
  return orders.get(orderId);
}

export { STORE_ID, STORE_NAME };

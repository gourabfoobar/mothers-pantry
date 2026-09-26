import { callKirana } from "../mcp/kiranaClient.js";
import { normalizeUnit } from "../services/units.js";
import type {
  ProviderClient,
  ProviderContext,
  ProviderSearchHit,
  ProviderAllocation,
  ProviderOrder,
} from "./types.js";

interface KiranaSearchHit {
  itemId: string;
  name: string;
  matchedAlias: string;
  score: number;
  packs: { size: number; unit: string; price: number; stockCount: number }[];
}

interface KiranaAllocation {
  itemId: string;
  requestedQty: number;
  requestedUnit: string;
  packs: { size: number; unit: string; count: number; price: number }[];
  fulfilledQty: number;
  fulfilledUnit: string;
  roundedDown: boolean;
  outOfStock: boolean;
  lineTotal: number;
}

function describePacks(packs: KiranaAllocation["packs"]): string {
  return packs.map((p) => `${p.count} × ${p.size} ${p.unit}`).join(", ");
}

/** Adapter over the local mock MCP server — the always-available dev/demo path. */
export const kiranaProvider: ProviderClient = {
  id: "kirana-now",

  async ensureCart(_ctx: ProviderContext) {
    const cart = await callKirana<{ id: string }>("create_cart", {});
    if (!cart.ok || !cart.data) throw new Error(`kirana-now unreachable: ${cart.error}`);
    return { cartId: cart.data.id };
  },

  async searchProducts(_ctx, query) {
    const result = await callKirana<KiranaSearchHit[]>("search_products", { query, limit: 5 });
    if (!result.ok || !result.data) return [];
    return result.data.map((hit): ProviderSearchHit => ({
      itemId: hit.itemId,
      name: hit.name,
      matchedAlias: hit.matchedAlias,
      score: hit.score,
      price: hit.packs[0]?.price,
    }));
  },

  async updateCartItem(_ctx, cartId, itemId, requestedQty, requestedUnit) {
    // Normalize "gm"/"litre"/"dozen"/etc. to what kirana-now's own allocator
    // understands (g/kg/ml/l/pcs); a unit that's still unrecognized after
    // that (e.g. "bundle") is passed through as-is so kirana-now's own
    // pack-count fallback — the deliberate "assumed unit" signal — kicks in.
    const normalized = normalizeUnit(requestedQty, requestedUnit);
    const qty = normalized ? normalized.qty : requestedQty;
    const unit = normalized ? normalized.unit : requestedUnit;

    const result = await callKirana<{ allocation: KiranaAllocation }>("update_cart_item", {
      cartId,
      itemId,
      requestedQty: qty,
      requestedUnit: unit,
    });
    if (!result.ok || !result.data) throw new Error(`kirana-now update_cart_item failed: ${result.error}`);
    const a = result.data.allocation;
    return {
      itemId: a.itemId,
      requestedQty,
      requestedUnit,
      fulfilledQty: a.fulfilledQty,
      fulfilledUnit: a.fulfilledUnit,
      packDescription: describePacks(a.packs),
      roundedDown: a.roundedDown,
      outOfStock: a.outOfStock,
      lineTotal: a.lineTotal,
    };
  },

  async removeCartItem(_ctx, cartId, lineId) {
    await callKirana("remove_cart_item", { cartId, lineId });
  },

  async getCartTotal(_ctx, cartId) {
    const result = await callKirana<{ total: number }>("get_cart", { cartId });
    return result.ok ? result.data?.total ?? 0 : 0;
  },

  async placeOrder(_ctx, cartId): Promise<ProviderOrder> {
    const result = await callKirana<{
      id: string;
      status: ProviderOrder["status"];
      total: number;
      courierName: string;
      courierDistanceKm: number;
      etaAt: string;
      events: ProviderOrder["events"];
    }>("place_order", { cartId });
    if (!result.ok || !result.data) throw new Error(`kirana-now place_order failed: ${result.error}`);
    return { ...result.data };
  },

  async getOrderStatus(_ctx, orderId): Promise<ProviderOrder> {
    const result = await callKirana<{
      id: string;
      status: ProviderOrder["status"];
      total: number;
      courierName: string;
      courierDistanceKm: number;
      etaAt: string;
      events: ProviderOrder["events"];
    }>("get_order_status", { orderId });
    if (!result.ok || !result.data) throw new Error(`kirana-now get_order_status failed: ${result.error}`);
    return { ...result.data };
  },
};

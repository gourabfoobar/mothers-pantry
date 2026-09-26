import { db } from "../db/index.js";
import { callSwiggyInstamart } from "./swiggyClient.js";
import { normalizeUnit } from "../services/units.js";
import type {
  ProviderClient,
  ProviderContext,
  ProviderSearchHit,
  ProviderAllocation,
  ProviderOrder,
  OrderStatus,
} from "./types.js";

interface SwiggyVariation {
  spinId: string;
  skuId: string;
  quantityDescription: string;
  price: { mrp: number; offerPrice: number };
  isInStockAndAvailable: boolean;
  maxQuantity?: number;
}

interface SwiggyProduct {
  displayName: string;
  productId: string;
  inStock: boolean;
  isAvail: boolean;
  variations: SwiggyVariation[];
}

interface CartLine {
  productId: string;
  spinId: string;
  skuId: string;
  quantity: number;
}

// Swiggy has no "get product by id" tool — search_products is the only
// lookup, so we remember what a search turned up long enough to act on it.
const productCache = new Map<string, SwiggyProduct>();
// update_cart REPLACES the whole cart, so we keep the running set ourselves
// and resend it in full on every change (per the multi-turn-state guidance).
const cartLines = new Map<string, CartLine[]>();

function getAccessToken(userId: string): string {
  const row = db
    .prepare("SELECT access_token as token, expires_at as expiresAt FROM provider_connections WHERE user_id = ? AND provider_id = 'swiggy' ORDER BY connected_at DESC LIMIT 1")
    .get(userId) as { token: string; expiresAt: string } | undefined;
  if (!row?.token) throw new Error("Swiggy is not connected for this user");
  if (row.expiresAt && new Date(row.expiresAt).getTime() < Date.now()) {
    throw new Error("Swiggy session expired — reconnect required");
  }
  return row.token;
}

function parseQuantityDescription(desc: string): { qty: number; unit: string } | undefined {
  const match = desc.match(/([\d.]+)\s*([a-zA-Z]+)/);
  if (!match) return undefined;
  const normalized = normalizeUnit(Number(match[1]), match[2]);
  return normalized ? { qty: normalized.qty, unit: normalized.unit } : undefined;
}

function baseSize(v: SwiggyVariation): number {
  return parseQuantityDescription(v.quantityDescription)?.qty ?? 0;
}

async function pushCart(token: string, ctx: ProviderContext, cartId: string) {
  const lines = cartLines.get(cartId) ?? [];
  if (lines.length === 0) {
    await callSwiggyInstamart(token, "clear_cart", {});
    return;
  }
  await callSwiggyInstamart(token, "update_cart", {
    selectedAddressId: ctx.providerAddressId,
    items: lines.map((l) => ({ spinId: l.spinId, skuId: l.skuId, quantity: l.quantity })),
  });
}

function mapStatus(statusText: string | undefined, delivered: boolean | undefined): OrderStatus {
  if (delivered) return "delivered";
  const s = (statusText ?? "").toLowerCase();
  if (s.includes("deliver")) return "delivered";
  if (s.includes("way") || s.includes("dispatch") || s.includes("picked") || s.includes("out for")) return "on_the_way";
  if (s.includes("pack")) return "packed";
  return "placed";
}

/**
 * Adapter over the real Swiggy Instamart MCP server
 * (https://mcp.swiggy.com/builders/docs/reference/instamart). This is the
 * default provider — kirana-now exists alongside it as an
 * always-available demo/offline fallback. Untested against a live Swiggy
 * account (this environment has no Swiggy staging credentials); built
 * strictly to the published tool contracts.
 */
export const swiggyProvider: ProviderClient = {
  id: "swiggy",

  async ensureCart(ctx) {
    const cartId = `${ctx.userId}:${ctx.providerAddressId}`;
    cartLines.set(cartId, []);
    return { cartId };
  },

  async searchProducts(ctx, query) {
    const token = getAccessToken(ctx.userId);
    const result = await callSwiggyInstamart<{ products: SwiggyProduct[] }>(token, "search_products", {
      addressId: ctx.providerAddressId,
      query,
    });
    if (!result.success || !result.data) return [];

    return result.data.products.map((product, index): ProviderSearchHit => {
      productCache.set(`${ctx.providerAddressId}::${product.productId}`, product);
      const cheapest = [...product.variations].sort((a, b) => a.price.offerPrice - b.price.offerPrice)[0];
      const available = product.isAvail && product.inStock;
      return {
        itemId: product.productId,
        name: product.displayName,
        matchedAlias: query,
        // Swiggy's search is already relevance-ranked but returns no score;
        // approximate one so the existing confidence-threshold logic still applies.
        score: available ? (index === 0 ? 1 : 0.75) : 0.4,
        price: cheapest?.price.offerPrice,
      };
    });
  },

  async updateCartItem(ctx, cartId, itemId, requestedQty, requestedUnit) {
    const token = getAccessToken(ctx.userId);
    const product = productCache.get(`${ctx.providerAddressId}::${itemId}`);
    if (!product) throw new Error("Swiggy product not found in this session — search again before updating the cart");

    const normalized = normalizeUnit(requestedQty, requestedUnit);
    const requestedBase = normalized ? normalized.qty : requestedQty;
    const inStock = product.variations.filter((v) => v.isInStockAndAvailable && baseSize(v) > 0);
    const best = [...inStock].sort((a, b) => baseSize(b) - baseSize(a))[0];

    if (!best) {
      return {
        itemId,
        requestedQty,
        requestedUnit,
        fulfilledQty: 0,
        fulfilledUnit: requestedUnit,
        packDescription: "",
        roundedDown: true,
        outOfStock: true,
        lineTotal: 0,
      };
    }

    const size = baseSize(best);
    const desiredCount = Math.max(1, Math.floor(requestedBase / size) || 1);
    const cap = best.maxQuantity ?? 99;
    let count = Math.min(desiredCount, cap);

    const lines = cartLines.get(cartId) ?? [];
    const withoutThis = lines.filter((l) => l.productId !== itemId);
    withoutThis.push({ productId: itemId, spinId: best.spinId, skuId: best.skuId, quantity: count });
    cartLines.set(cartId, withoutThis);

    const pushResult = await callSwiggyInstamart<{
      reducedQuantityItems?: { spinId: string; cappedQuantity: number }[];
    }>(token, "update_cart", {
      selectedAddressId: ctx.providerAddressId,
      items: withoutThis.map((l) => ({ spinId: l.spinId, skuId: l.skuId, quantity: l.quantity })),
    });

    const reduced = pushResult.data?.reducedQuantityItems?.find((r) => r.spinId === best.spinId);
    if (reduced) {
      count = reduced.cappedQuantity;
      withoutThis[withoutThis.length - 1].quantity = count;
      cartLines.set(cartId, withoutThis);
    }

    const fulfilledQty = count * size;
    return {
      itemId,
      requestedQty,
      requestedUnit,
      fulfilledQty,
      fulfilledUnit: normalized?.unit ?? requestedUnit,
      packDescription: `${count} × ${best.quantityDescription}`,
      roundedDown: fulfilledQty < requestedBase || Boolean(reduced),
      outOfStock: false,
      lineTotal: count * best.price.offerPrice,
    };
  },

  async removeCartItem(ctx, cartId, itemId) {
    const token = getAccessToken(ctx.userId);
    const lines = (cartLines.get(cartId) ?? []).filter((l) => l.productId !== itemId);
    cartLines.set(cartId, lines);
    await pushCart(token, ctx, cartId);
  },

  async getCartTotal(ctx, _cartId) {
    const token = getAccessToken(ctx.userId);
    const result = await callSwiggyInstamart<{ cartTotalAmount: string }>(token, "get_cart", {});
    if (!result.success || !result.data) return 0;
    return Number(result.data.cartTotalAmount.replace(/[^\d.]/g, "")) || 0;
  },

  async placeOrder(ctx, _cartId): Promise<ProviderOrder> {
    const token = getAccessToken(ctx.userId);
    const options = await callSwiggyInstamart<{ cod?: { available: boolean }; swiggyMoney?: { available: boolean } }>(
      token,
      "get_payment_options",
      { addressId: ctx.providerAddressId },
    );
    const paymentMethod = options.data?.cod?.available ? "Cash" : options.data?.swiggyMoney?.available ? "SwiggyPay" : "Cash";

    const result = await callSwiggyInstamart<{ orderId: string; status: string; cartTotal?: number }>(token, "checkout", {
      addressId: ctx.providerAddressId,
      paymentMethod,
    });
    if (!result.success || !result.data) {
      throw new Error(`Swiggy checkout failed: ${result.error?.message ?? result.message ?? "unknown error"}`);
    }
    const now = new Date().toISOString();
    return {
      id: result.data.orderId,
      status: "placed",
      total: result.data.cartTotal ?? 0,
      events: [{ status: "placed", label: "Order placed", at: now }],
    };
  },

  async getOrderStatus(ctx, orderId): Promise<ProviderOrder> {
    const token = getAccessToken(ctx.userId);
    const result = await callSwiggyInstamart<{
      deliveryBy: number | null;
      statusText?: string;
      delivered?: boolean;
      cancelled?: boolean;
    }>(token, "get_delivery_status", { orderId, addressId: ctx.providerAddressId });
    if (!result.success || !result.data) {
      throw new Error(`Swiggy get_delivery_status failed: ${result.error?.message ?? "unknown error"}`);
    }
    const status = mapStatus(result.data.statusText, result.data.delivered);
    return {
      id: orderId,
      status,
      total: 0,
      etaAt: result.data.deliveryBy ? new Date(result.data.deliveryBy).toISOString() : undefined,
      events: [{ status, label: result.data.statusText ?? status, at: new Date().toISOString() }],
    };
  },
};

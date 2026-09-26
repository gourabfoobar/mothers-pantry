/**
 * Every grocery provider (the mock kirana-now MCP server, or the real
 * Swiggy Instamart MCP server) is normalized to this shape so the matcher,
 * cart and order routes never branch on which provider is connected.
 */

export interface ProviderSearchHit {
  /** Opaque, provider-specific reference the rest of the app treats as a black box. */
  itemId: string;
  name: string;
  matchedAlias: string;
  score: number;
  price?: number;
}

export interface ProviderAllocation {
  itemId: string;
  requestedQty: number;
  requestedUnit: string;
  fulfilledQty: number;
  fulfilledUnit: string;
  /** Human-readable pack breakdown, e.g. "2 × 2 kg" — empty when the provider has no pack concept. */
  packDescription: string;
  roundedDown: boolean;
  outOfStock: boolean;
  lineTotal: number;
}

export type OrderStatus = "placed" | "packed" | "on_the_way" | "delivered";

export interface ProviderOrderEvent {
  status: OrderStatus;
  label: string;
  at: string;
}

export interface ProviderOrder {
  id: string;
  status: OrderStatus;
  total: number;
  courierName?: string;
  courierDistanceKm?: number;
  etaAt?: string;
  events: ProviderOrderEvent[];
}

export interface ProviderContext {
  userId: string;
  /** The provider's own address id (from get_addresses for Swiggy, or our local address id for kirana-now). */
  providerAddressId: string;
}

export interface ProviderClient {
  readonly id: string;

  /** Returns a cart handle to pass to the other cart methods. */
  ensureCart(ctx: ProviderContext): Promise<{ cartId: string }>;

  searchProducts(ctx: ProviderContext, query: string): Promise<ProviderSearchHit[]>;

  /** Sets this item's line to the requested quantity; returns what was actually allocated. */
  updateCartItem(
    ctx: ProviderContext,
    cartId: string,
    itemId: string,
    requestedQty: number,
    requestedUnit: string,
  ): Promise<ProviderAllocation>;

  removeCartItem(ctx: ProviderContext, cartId: string, itemId: string): Promise<void>;

  getCartTotal(ctx: ProviderContext, cartId: string): Promise<number>;

  placeOrder(ctx: ProviderContext, cartId: string): Promise<ProviderOrder>;

  getOrderStatus(ctx: ProviderContext, orderId: string): Promise<ProviderOrder>;
}

export class ProviderUnavailableError extends Error {
  constructor(
    public providerId: string,
    message: string,
  ) {
    super(message);
  }
}

export class ProviderReauthRequiredError extends Error {
  constructor(public providerId: string) {
    super(`${providerId} session expired — reconnect required`);
  }
}

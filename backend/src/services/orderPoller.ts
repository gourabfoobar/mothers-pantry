import { randomUUID } from "node:crypto";
import { db } from "../db/index.js";
import { providerById } from "../providers/registry.js";
import type { OrderStatus, ProviderContext, ProviderOrder } from "../providers/types.js";
import { pushProvider, type LiveActivityContentState } from "./apns.js";

const ETA_LABELS: Record<OrderStatus, string> = {
  placed: "Order placed",
  packed: "Packed",
  on_the_way: "On the way",
  delivered: "Delivered",
};

function contentState(order: ProviderOrder): LiveActivityContentState {
  return { status: ETA_LABELS[order.status], etaText: order.etaAt ? new Date(order.etaAt).toLocaleTimeString() : "" };
}

async function pollOnce() {
  const active = db
    .prepare(
      `SELECT o.id, o.provider_order_id as providerOrderId, o.status, o.activity_push_token as activityPushToken,
              o.user_id as userId, addr.provider_id as providerId, addr.provider_address_id as providerAddressId
       FROM orders o
       JOIN addresses addr ON addr.id = o.address_id
       WHERE o.status != 'delivered'`,
    )
    .all() as {
    id: string;
    providerOrderId: string;
    status: OrderStatus;
    activityPushToken: string | null;
    userId: string;
    providerId: string | null;
    providerAddressId: string | null;
  }[];

  for (const local of active) {
    const provider = providerById(local.providerId ?? "kirana-now");
    if (!provider) continue;
    const ctx: ProviderContext = { userId: local.userId, providerAddressId: local.providerAddressId ?? "" };

    let remote: ProviderOrder;
    try {
      remote = await provider.getOrderStatus(ctx, local.providerOrderId);
    } catch (err) {
      console.error(`[order-poller] ${provider.id} status check failed for ${local.id}`, err);
      continue;
    }
    if (remote.status === local.status) continue;

    db.prepare("UPDATE orders SET status = ?, courier_distance_km = ? WHERE id = ?").run(
      remote.status,
      remote.courierDistanceKm ?? null,
      local.id,
    );
    for (const event of remote.events) {
      const seen = db.prepare("SELECT 1 FROM order_events WHERE order_id = ? AND type = ?").get(local.id, event.status);
      if (seen) continue;
      db.prepare("INSERT INTO order_events (id, order_id, type, label, at) VALUES (?, ?, ?, ?, ?)").run(
        randomUUID(),
        local.id,
        event.status,
        event.label,
        event.at,
      );
    }

    if (local.activityPushToken) {
      if (remote.status === "delivered") {
        await pushProvider.sendLiveActivityEnd(local.activityPushToken, contentState(remote));
      } else {
        await pushProvider.sendLiveActivityUpdate(local.activityPushToken, contentState(remote), 30 * 60);
      }
    }
  }
}

let timer: NodeJS.Timeout | undefined;

export function startOrderPoller(intervalMs = Number(process.env.ORDER_POLL_INTERVAL_MS ?? 5000)) {
  if (timer) return;
  timer = setInterval(() => {
    pollOnce().catch((err) => console.error("[order-poller] failed", err));
  }, intervalMs);
}

export function stopOrderPoller() {
  if (timer) clearInterval(timer);
  timer = undefined;
}

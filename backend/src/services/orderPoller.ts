import { randomUUID } from "node:crypto";
import { db } from "../db/index.js";
import { providerById } from "../providers/registry.js";
import type { OrderStatus, ProviderContext, ProviderOrder } from "../providers/types.js";
import { pushProvider, type LiveActivityContentState } from "./apns.js";

function contentState(order: ProviderOrder, itemCount: number, total: number): LiveActivityContentState {
  return {
    stage: order.status,
    etaText: order.etaAt ? new Date(order.etaAt).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }) : "",
    etaAtISO: order.etaAt,
    courierName: order.courierName,
    courierDistanceKm: order.courierDistanceKm,
    itemCount,
    total,
  };
}

async function pollOnce() {
  const active = db
    .prepare(
      `SELECT o.id, o.provider_order_id as providerOrderId, o.status, o.activity_push_token as activityPushToken,
              o.user_id as userId, o.total as total, o.list_id as listId,
              addr.provider_id as providerId, addr.provider_address_id as providerAddressId,
              (SELECT count(*) FROM order_items oi WHERE oi.list_id = o.list_id AND oi.status != 'rejected') as itemCount
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
    total: number;
    listId: string;
    providerId: string | null;
    providerAddressId: string | null;
    itemCount: number;
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
      const state = contentState(remote, local.itemCount, local.total);
      if (remote.status === "delivered") {
        await pushProvider.sendLiveActivityEnd(local.activityPushToken, state);
      } else {
        await pushProvider.sendLiveActivityUpdate(local.activityPushToken, state, 30 * 60);
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

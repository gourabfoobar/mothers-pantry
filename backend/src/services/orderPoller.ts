import { randomUUID } from "node:crypto";
import { db } from "../db/index.js";
import { callKirana } from "../mcp/kiranaClient.js";
import { pushProvider, type LiveActivityContentState } from "./apns.js";

interface ProviderOrder {
  id: string;
  status: "placed" | "packed" | "on_the_way" | "delivered";
  events: { status: string; label: string; at: string }[];
  courierName: string;
  courierDistanceKm: number;
  etaAt: string;
}

const ETA_LABELS: Record<ProviderOrder["status"], string> = {
  placed: "Order placed",
  packed: "Packed",
  on_the_way: "On the way",
  delivered: "Delivered",
};

function contentState(order: ProviderOrder): LiveActivityContentState {
  return { status: ETA_LABELS[order.status], etaText: new Date(order.etaAt).toLocaleTimeString() };
}

async function pollOnce() {
  const active = db
    .prepare(
      `SELECT id, provider_order_id as providerOrderId, status, activity_push_token as activityPushToken
       FROM orders WHERE status != 'delivered'`,
    )
    .all() as { id: string; providerOrderId: string; status: string; activityPushToken: string | null }[];

  for (const local of active) {
    const result = await callKirana<ProviderOrder>("get_order_status", { orderId: local.providerOrderId });
    if (!result.ok || !result.data) continue;
    const remote = result.data;
    if (remote.status === local.status) continue;

    db.prepare("UPDATE orders SET status = ?, courier_distance_km = ? WHERE id = ?").run(
      remote.status,
      remote.courierDistanceKm,
      local.id,
    );
    const newEvents = remote.events.filter((e) => !db.prepare("SELECT 1 FROM order_events WHERE order_id = ? AND type = ?").get(local.id, e.status));
    for (const event of newEvents) {
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

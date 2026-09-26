import { db } from "../db/index.js";
import { pushProvider } from "./apns.js";

export const MATCH_APPROVAL_CATEGORY = "PANTRY_MATCH_APPROVAL";
export const QTY_APPROVAL_CATEGORY = "PANTRY_QTY_APPROVAL";

/**
 * Fires one actionable notification per item that needs a look (canvas 4.1 —
 * the Lock Screen shows one card per pending approval, not a single digest).
 * Silently does nothing if the user has no registered device or notifications
 * are off; this is best-effort, not part of the request/response contract.
 */
export async function notifyNeedsApproval(listId: string): Promise<void> {
  const list = db
    .prepare(
      `SELECT gl.user_id as userId, u.notifications_enabled as notificationsEnabled
       FROM grocery_lists gl JOIN users u ON u.id = gl.user_id WHERE gl.id = ?`,
    )
    .get(listId) as { userId: string; notificationsEnabled: number } | undefined;
  if (!list || !list.notificationsEnabled) return;

  const device = db
    .prepare("SELECT push_token as pushToken FROM devices WHERE user_id = ? AND push_token IS NOT NULL ORDER BY registered_at DESC LIMIT 1")
    .get(list.userId) as { pushToken: string } | undefined;
  if (!device?.pushToken) return;

  const items = db
    .prepare(
      `SELECT oi.id, oi.catalog_item_name as catalogItemName, oi.status, oi.rounded_down as roundedDown,
              oi.approved_qty as approvedQty, oi.requested_unit as requestedUnit, ll.raw_text as rawText
       FROM order_items oi JOIN list_lines ll ON ll.id = oi.line_id
       WHERE oi.list_id = ? AND oi.status IN ('needs_match', 'needs_qty')`,
    )
    .all(listId) as { id: string; catalogItemName: string; status: string; roundedDown: number; approvedQty: number; requestedUnit: string; rawText: string }[];

  for (const item of items) {
    if (item.status === "needs_qty") {
      await pushProvider.sendActionableNotification(device.pushToken, {
        title: `Rounded down: ${item.catalogItemName}`,
        body: `${item.rawText} asked · ${item.approvedQty} ${item.requestedUnit} in stock. Approve?`,
        categoryId: QTY_APPROVAL_CATEGORY,
        userInfo: { orderItemId: item.id, kind: "qty" },
      });
    } else {
      await pushProvider.sendActionableNotification(device.pushToken, {
        title: `Which "${item.rawText}"?`,
        body: `We think Ma means ${item.catalogItemName}. Tap to check.`,
        categoryId: MATCH_APPROVAL_CATEGORY,
        userInfo: { orderItemId: item.id, kind: "match" },
      });
    }
  }
}

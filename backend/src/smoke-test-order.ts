const BASE = process.env.PANTRY_API_URL ?? "http://localhost:4200";

async function post(path: string, body: unknown, token?: string) {
  const res = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => undefined);
  if (!res.ok) throw new Error(`${path} -> ${res.status}: ${JSON.stringify(json)}`);
  return json;
}

async function get(path: string, token?: string) {
  const res = await fetch(`${BASE}${path}`, { headers: token ? { authorization: `Bearer ${token}` } : {} });
  const json = await res.json().catch(() => undefined);
  if (!res.ok) throw new Error(`${path} -> ${res.status}: ${JSON.stringify(json)}`);
  return json;
}

const SHORT_LIST = `Chini 1 kg\nAloo 3 kg`;

async function main() {
  const phone = `+91${Math.floor(6_000_000_000 + Math.random() * 3_000_000_000)}`;
  const { devCode } = await post("/auth/otp/request", { phone });
  const { token } = await post("/auth/otp/verify", { phone, code: devCode });
  await post("/auth/profile", { name: "Gourab" }, token);
  await post("/providers/kirana-now/authorize", {}, token);
  const recipient = await post("/recipients", { name: "Mita Ghosh", relation: "Ma" }, token);
  const address = await post("/addresses", { recipientId: recipient.id, label: "Ma's home", line1: "12B Hindusthan Park" }, token);

  const created = await post("/lists", { addressId: address.id, rawText: SHORT_LIST }, token);
  const review = await post(`/lists/${created.listId}/match`, {}, token);
  console.log("review: all approved already? ", review.items.every((i: any) => i.status === "approved"));

  const cartBefore = await get(`/orders/cart/${created.listId}`, token);
  console.log("cart ready:", cartBefore.ready, "total:", cartBefore.total);
  if (!cartBefore.ready) throw new Error("expected cart to be ready — both items should auto-match");

  const placedOrder = await post(`/orders/place/${created.listId}`, {}, token);
  console.log("order placed:", placedOrder);

  await post(`/orders/${placedOrder.id}/activity-token`, { token: "fake-activity-token-for-smoke-test" }, token);

  const history = await get("/orders", token);
  console.log("history:", history);
  if (history.length !== 1 || history[0].id !== placedOrder.id) throw new Error("order missing from history");

  console.log("waiting for the order-status poller to pick up 'packed'...");
  let detail;
  for (let i = 0; i < 12; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    detail = await get(`/orders/${placedOrder.id}`, token);
    console.log(`  t+${(i + 1) * 2}s -> status=${detail.status} events=${detail.events.length}`);
    if (detail.status !== "placed") break;
  }
  if (!detail || detail.status === "placed") throw new Error("expected the poller to have advanced the order past 'placed'");

  console.log("SMOKE TEST (order lifecycle) PASSED");
}

main().catch((err) => {
  console.error("SMOKE TEST FAILED", err);
  process.exit(1);
});

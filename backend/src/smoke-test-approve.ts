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

const MAS_LIST = `Atta 5 kg\nKalo jeera 100 gm\nDhoniya pata 2 bundle`;

async function main() {
  const phone = `+91${Math.floor(6_000_000_000 + Math.random() * 3_000_000_000)}`;
  const { devCode } = await post("/auth/otp/request", { phone });
  const { token } = await post("/auth/otp/verify", { phone, code: devCode });
  await post("/auth/profile", { name: "Gourab" }, token);
  await post("/providers/kirana-now/authorize", {}, token);
  const recipient = await post("/recipients", { name: "Mita Ghosh", relation: "Ma" }, token);
  const address = await post("/addresses", { recipientId: recipient.id, label: "Ma's home", line1: "12B Hindusthan Park" }, token);
  const created = await post("/lists", { addressId: address.id, rawText: MAS_LIST }, token);
  const review = await post(`/lists/${created.listId}/match`, {}, token);

  const atta = review.items.find((i: any) => i.rawText === "Atta 5 kg");
  const kalo = review.items.find((i: any) => i.rawText === "Kalo jeera 100 gm");
  const dhoniya = review.items.find((i: any) => i.rawText.startsWith("Dhoniya"));

  await post(`/qty/${atta.id}/approve`, {}, token);
  await post(`/matches/${kalo.id}/approve`, { catalogItemId: "black-cumin" }, token); // switch away from the default
  await post(`/matches/${dhoniya.id}/reject`, {}, token);

  const finalReview = await fetch(`${BASE}/lists/${created.listId}/review`, { headers: { authorization: `Bearer ${token}` } }).then((r) => r.json());

  const finalAtta = finalReview.items.find((i: any) => i.rawText === "Atta 5 kg");
  const finalKalo = finalReview.items.find((i: any) => i.rawText === "Kalo jeera 100 gm");
  const finalDhoniya = finalReview.items.find((i: any) => i.rawText.startsWith("Dhoniya"));

  console.log("atta after approve:", finalAtta.status, finalAtta.approvedQty);
  console.log("kalo after switch+approve:", finalKalo.status, finalKalo.catalogItemName, finalKalo.lineTotal);
  console.log("dhoniya after reject:", finalDhoniya.status);

  if (finalAtta.status !== "approved" || finalAtta.approvedQty !== 4) throw new Error("atta qty approval failed");
  if (finalKalo.status !== "approved" || finalKalo.catalogItemName !== "Black cumin (shahi jeera)" || finalKalo.lineTotal !== 120) {
    throw new Error("kalo jeera switch-and-approve failed");
  }
  if (finalDhoniya.status !== "rejected") throw new Error("dhoniya reject failed");

  console.log("SMOKE TEST (approve/reject) PASSED");
}

main().catch((err) => {
  console.error("SMOKE TEST FAILED", err);
  process.exit(1);
});

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

const MAS_LIST = `Babu ei list ta order kore dis
Atta 5 kg
Chini 1 kg
Dhoniya pata 2 bundle
Aloo 3 kg
Peyaj 2 kg
Sorsher tel 1 litre
Musur dal 1 kg
Haldi 200 gm
Kalo jeera 100 gm
Doi 500 gm
Kacha lanka 100 gm
Posto 100 gm`;

async function main() {
  const phone = `+91${Math.floor(6_000_000_000 + Math.random() * 3_000_000_000)}`;
  const { devCode } = await post("/auth/otp/request", { phone });
  const { token } = await post("/auth/otp/verify", { phone, code: devCode });
  await post("/auth/profile", { name: "Gourab" }, token);
  await post("/providers/kirana-now/authorize", {}, token);
  const recipient = await post("/recipients", { name: "Mita Ghosh", relation: "Ma" }, token);
  const address = await post(
    "/addresses",
    { recipientId: recipient.id, label: "Ma's home", line1: "12B Hindusthan Park", pincode: "700029" },
    token,
  );

  const created = await post("/lists", { addressId: address.id, rawText: MAS_LIST }, token);
  console.log("list created ->", created);
  if (created.itemCount !== 12) throw new Error(`expected 12 items, got ${created.itemCount}`);
  if (created.greetingCount !== 1) throw new Error(`expected 1 greeting line, got ${created.greetingCount}`);

  const review = await post(`/lists/${created.listId}/match`, {}, token);
  console.log("\n--- review ---");
  console.log(`itemCount=${review.itemCount} matched=${review.matchedCount} needs=${review.needsCount} roundedDown=${review.roundedDownCount} total=₹${review.total}`);
  for (const item of review.items) {
    console.log(`  [${item.status}]${item.roundedDown ? " (rounded down)" : ""} "${item.rawText}" -> ${item.catalogItemName} (₹${item.lineTotal})`);
    if (item.status !== "approved") {
      for (const c of item.candidates) console.log(`      candidate: ${c.name} (${c.confidence.toFixed(2)}) - ${c.reason}`);
    }
  }

  const atta = review.items.find((i: any) => i.rawText === "Atta 5 kg");
  if (!atta || !atta.roundedDown || atta.lineTotal !== 236) {
    throw new Error(`expected atta rounded down to ₹236, got ${JSON.stringify(atta)}`);
  }
  const kalo = review.items.find((i: any) => i.rawText === "Kalo jeera 100 gm");
  if (!kalo || kalo.status !== "needs_match" || kalo.candidates.length < 2) {
    throw new Error(`expected kalo jeera to need a match with 2+ candidates, got ${JSON.stringify(kalo)}`);
  }

  console.log("\nSMOKE TEST (matching) PASSED");
}

main().catch((err) => {
  console.error("SMOKE TEST FAILED", err);
  process.exit(1);
});

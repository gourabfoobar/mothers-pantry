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
  const res = await fetch(`${BASE}${path}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
  const json = await res.json().catch(() => undefined);
  if (!res.ok) throw new Error(`${path} -> ${res.status}: ${JSON.stringify(json)}`);
  return json;
}

async function main() {
  const phone = `+91${Math.floor(6_000_000_000 + Math.random() * 3_000_000_000)}`;

  const requested = await post("/auth/otp/request", { phone });
  console.log("otp requested ->", requested);
  if (!requested.devCode) throw new Error("expected devCode in dev mode");

  const verified = await post("/auth/otp/verify", { phone, code: requested.devCode });
  console.log("otp verified ->", verified);
  if (!verified.isNewUser) throw new Error("expected a brand-new user");
  const token = verified.token as string;

  const profile = await post("/auth/profile", { name: "Gourab", email: "gourab@example.com" }, token);
  console.log("profile set ->", profile);
  if (profile.name !== "Gourab") throw new Error("profile update did not stick");

  const providers = await get("/providers");
  console.log("providers ->", providers.map((p: any) => p.id));
  if (!providers.some((p: any) => p.id === "kirana-now" && p.available)) throw new Error("kirana-now missing");

  const connection = await post("/providers/kirana-now/authorize", {}, token);
  console.log("connected ->", connection);
  if (connection.storeName !== "Kirana Now, Gariahat") throw new Error("did not reach the live kirana-now MCP server");

  const gotConnection = await get("/providers/connection", token);
  console.log("connection status ->", gotConnection);
  if (gotConnection.providerId !== "kirana-now") throw new Error("connection did not persist");

  const recipient = await post("/recipients", { name: "Mita Ghosh", relation: "Ma", phone: "+919830012345" }, token);
  console.log("recipient created ->", recipient);

  const address = await post(
    "/addresses",
    { recipientId: recipient.id, label: "Ma's home", line1: "12B Hindusthan Park", city: "Kolkata", pincode: "700029" },
    token,
  );
  console.log("address created ->", address);

  const secondVerify = await post("/auth/otp/verify", {
    phone,
    code: (await post("/auth/otp/request", { phone })).devCode,
  });
  console.log("returning-user verify ->", secondVerify);
  if (secondVerify.isNewUser) throw new Error("returning user should not be flagged new");

  console.log("SMOKE TEST PASSED");
}

main().catch((err) => {
  console.error("SMOKE TEST FAILED", err);
  process.exit(1);
});

import { db } from "../db/index.js";
import { callSwiggyInstamart } from "./swiggyClient.js";
import type { ProviderClient } from "./types.js";

interface LocalAddress {
  id: string;
  label: string;
  line1: string;
  city: string | null;
  pincode: string | null;
  providerId: string | null;
  providerAddressId: string | null;
}

/**
 * kirana-now accepts our own address id as-is. Swiggy needs its own
 * addressId (from create_address/get_addresses) — created once per address
 * and cached on the row, since re-creating it on every list would spam
 * duplicate saved addresses on the user's real Swiggy account.
 */
export async function resolveProviderAddressId(provider: ProviderClient, userId: string, addressId: string): Promise<string> {
  if (provider.id === "kirana-now") return addressId;

  const address = db
    .prepare(
      `SELECT id, label, line1, city, pincode, provider_id as providerId, provider_address_id as providerAddressId
       FROM addresses WHERE id = ? AND user_id = ?`,
    )
    .get(addressId, userId) as LocalAddress | undefined;
  if (!address) throw new Error("address_not_found");

  if (address.providerId === provider.id && address.providerAddressId) {
    return address.providerAddressId;
  }

  if (provider.id === "swiggy") {
    const user = db.prepare("SELECT name, phone FROM users WHERE id = ?").get(userId) as
      | { name: string | null; phone: string }
      | undefined;
    const token = requireSwiggyToken(userId);

    const result = await callSwiggyInstamart<{ addressId: string }>(token, "create_address", {
      fullAddress: `${address.line1}, ${address.city ?? ""} ${address.pincode ?? ""}`.trim(),
      addressLine: address.line1,
      addressLine2: "",
      city: address.city ?? "",
      postalCode: address.pincode ?? "",
      addressCategory: "HOME",
      addressTag: address.label,
      userName: user?.name ?? "Mother's Pantry user",
      userPhone: user?.phone ?? "",
    });
    if (!result.success || !result.data) {
      throw new Error(`Could not create this address on Swiggy: ${result.error?.message ?? "unknown error"}`);
    }

    db.prepare("UPDATE addresses SET provider_id = 'swiggy', provider_address_id = ? WHERE id = ?").run(
      result.data.addressId,
      addressId,
    );
    return result.data.addressId;
  }

  throw new Error(`No address resolution strategy for provider "${provider.id}"`);
}

function requireSwiggyToken(userId: string): string {
  const row = db
    .prepare("SELECT access_token as token FROM provider_connections WHERE user_id = ? AND provider_id = 'swiggy' ORDER BY connected_at DESC LIMIT 1")
    .get(userId) as { token: string } | undefined;
  if (!row?.token) throw new Error("Swiggy is not connected for this user");
  return row.token;
}

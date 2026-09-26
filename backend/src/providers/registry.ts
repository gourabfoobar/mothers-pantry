import { db } from "../db/index.js";
import { kiranaProvider } from "./kirana.js";
import { swiggyProvider } from "./swiggy.js";
import type { ProviderClient } from "./types.js";

const PROVIDERS: Record<string, ProviderClient> = {
  [kiranaProvider.id]: kiranaProvider,
  [swiggyProvider.id]: swiggyProvider,
};

export function providerById(id: string): ProviderClient | undefined {
  return PROVIDERS[id];
}

/** The user's most recently connected provider, or the app default if none. */
export function activeProviderForUser(userId: string): ProviderClient {
  const row = db
    .prepare("SELECT provider_id as providerId FROM provider_connections WHERE user_id = ? ORDER BY connected_at DESC LIMIT 1")
    .get(userId) as { providerId: string } | undefined;
  const provider = row ? providerById(row.providerId) : undefined;
  return provider ?? PROVIDERS[DEFAULT_PROVIDER_ID] ?? kiranaProvider;
}

export const DEFAULT_PROVIDER_ID = process.env.PANTRY_DEFAULT_PROVIDER ?? "swiggy";

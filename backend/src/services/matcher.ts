import { callKirana } from "../mcp/kiranaClient.js";
import { normalizeUnit } from "./units.js";
import type { ParsedItem } from "./parser.js";

export const MATCH_CONFIDENCE_THRESHOLD = 0.9;
const TIE_EPSILON = 0.001;

export interface SearchHit {
  itemId: string;
  name: string;
  matchedAlias: string;
  score: number;
  packs: { size: number; unit: string; price: number; stockCount: number }[];
}

export interface Allocation {
  itemId: string;
  requestedQty: number;
  requestedUnit: string;
  packs: { size: number; unit: string; count: number; price: number }[];
  fulfilledQty: number;
  fulfilledUnit: string;
  roundedDown: boolean;
  outOfStock: boolean;
  lineTotal: number;
}

export type MatchStatus = "matched" | "needs_match" | "needs_qty";

export interface MatchCandidate {
  catalogItemId: string;
  name: string;
  confidence: number;
  reason: string;
  price?: number;
}

export interface MatchResult {
  status: MatchStatus;
  candidates: MatchCandidate[];
  chosen?: { catalogItemId: string; name: string };
  allocation?: Allocation;
}

function unresolvable(item: ParsedItem, reason: string): MatchResult {
  return { status: "needs_match", candidates: [{ catalogItemId: "", name: item.itemQuery, confidence: 0, reason }] };
}

export async function matchLine(cartId: string, item: ParsedItem): Promise<MatchResult> {
  const search = await callKirana<SearchHit[]>("search_products", { query: item.itemQuery, limit: 5 });
  const hits = search.ok ? search.data ?? [] : [];
  if (hits.length === 0) {
    return unresolvable(item, `Couldn't find anything in the catalogue for "${item.itemQuery}".`);
  }

  const [top, second] = hits;
  const isAmbiguous = second !== undefined && top.score - second.score < TIE_EPSILON && top.score >= 0.65;

  const normalized = normalizeUnit(item.requestedQty, item.requestedUnit);
  const unitIsAssumed = normalized === undefined;
  const confidence = unitIsAssumed ? top.score * 0.7 : top.score;

  const candidates: MatchCandidate[] = (isAmbiguous ? hits.slice(0, 2) : [top]).map((hit, i) => ({
    catalogItemId: hit.itemId,
    name: hit.name,
    confidence: i === 0 ? confidence : hit.score,
    reason:
      i === 0
        ? isAmbiguous
          ? `"${item.itemQuery}" could mean ${top.name} or ${second!.name} — most likely ${hit.name}.`
          : unitIsAssumed
            ? `Matched "${item.itemQuery}"; assumed what she means by "${item.requestedUnit}".`
            : `"${item.itemQuery}" matched to ${hit.name}.`
        : `Also called "${hit.matchedAlias}".`,
    price: hit.packs[0]?.price,
  }));

  // Even an unambiguous, high-confidence match still needs an allocation
  // preview — the "always round down" rule can turn any line into an
  // approval regardless of how sure we are about which item it is.
  const chosen = top;
  const packUnit = chosen.packs[0]?.unit ?? "pcs";
  const allocQty = normalized ? normalized.qty : item.requestedQty * (chosen.packs[0]?.size ?? 1);
  const allocUnit = normalized ? normalized.unit : packUnit;

  const allocationResult = await callKirana<{ allocation: Allocation }>("update_cart_item", {
    cartId,
    itemId: chosen.itemId,
    requestedQty: allocQty,
    requestedUnit: allocUnit,
  });
  const allocation = allocationResult.ok ? allocationResult.data?.allocation : undefined;

  let status: MatchStatus;
  if (allocation?.roundedDown) status = "needs_qty";
  else if (isAmbiguous || confidence < MATCH_CONFIDENCE_THRESHOLD) status = "needs_match";
  else status = "matched";

  return { status, candidates, chosen: { catalogItemId: chosen.itemId, name: chosen.name }, allocation };
}

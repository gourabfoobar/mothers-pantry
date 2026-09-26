/**
 * Normalizes the free-text unit Ma actually wrote ("gm", "litre", "dozen"...)
 * into the base unit family kirana-now's stock allocator understands
 * (g / ml / pcs). Returns undefined when the unit can't be mapped without
 * guessing — that's a real signal the match needs a human glance, not just
 * plumbing, so callers should treat it as a confidence penalty rather than
 * a hard failure.
 */
export interface NormalizedQty {
  qty: number;
  unit: "g" | "kg" | "ml" | "l" | "pcs";
}

const UNIT_ALIASES: Record<string, { unit: NormalizedQty["unit"]; multiplier: number }> = {
  kg: { unit: "kg", multiplier: 1 },
  kilo: { unit: "kg", multiplier: 1 },
  kilos: { unit: "kg", multiplier: 1 },
  kilogram: { unit: "kg", multiplier: 1 },
  kilograms: { unit: "kg", multiplier: 1 },
  g: { unit: "g", multiplier: 1 },
  gm: { unit: "g", multiplier: 1 },
  gms: { unit: "g", multiplier: 1 },
  gram: { unit: "g", multiplier: 1 },
  grams: { unit: "g", multiplier: 1 },
  l: { unit: "l", multiplier: 1 },
  litre: { unit: "l", multiplier: 1 },
  litres: { unit: "l", multiplier: 1 },
  liter: { unit: "l", multiplier: 1 },
  liters: { unit: "l", multiplier: 1 },
  ml: { unit: "ml", multiplier: 1 },
  pcs: { unit: "pcs", multiplier: 1 },
  pc: { unit: "pcs", multiplier: 1 },
  piece: { unit: "pcs", multiplier: 1 },
  pieces: { unit: "pcs", multiplier: 1 },
  dozen: { unit: "pcs", multiplier: 12 },
};

export function normalizeUnit(rawQty: number, rawUnit: string): NormalizedQty | undefined {
  const key = rawUnit.trim().toLowerCase().replace(/\.$/, "");
  const mapped = UNIT_ALIASES[key];
  if (!mapped) return undefined;
  return { qty: rawQty * mapped.multiplier, unit: mapped.unit };
}

export type PackUnit = "kg" | "g" | "l" | "ml" | "pcs" | "bundle";

export interface Pack {
  size: number;
  unit: PackUnit;
  price: number;
  /** Packs of this size physically available at the store right now. */
  stockCount: number;
}

export interface CatalogItem {
  id: string;
  name: string;
  category: string;
  /** Names/spellings (Bengali, Hindi, English, phonetic) that should find this item. */
  aliases: string[];
  packs: Pack[];
}

export const STORE_ID = "kirana-now-gariahat";
export const STORE_NAME = "Kirana Now, Gariahat";
export const STORE_PINCODE = "700029";

/**
 * Seeded so the whole demo flow — including the "always round down" rule —
 * runs end to end without any external dependency.
 *
 * `atta` is deliberately short-stocked: no 1 kg or 5 kg packs on hand, only
 * two 2 kg packs, so a request for "5 kg" can only ever resolve to 4 kg.
 */
export const CATALOG: CatalogItem[] = [
  {
    id: "atta-whole-wheat",
    name: "Whole wheat atta",
    category: "Atta & flours",
    aliases: ["atta", "wheat flour", "gehun ka atta", "flour"],
    packs: [
      { size: 1, unit: "kg", price: 62, stockCount: 0 },
      { size: 2, unit: "kg", price: 118, stockCount: 2 },
      { size: 5, unit: "kg", price: 280, stockCount: 0 },
    ],
  },
  {
    id: "sugar-refined",
    name: "Sugar, refined",
    category: "Sugar & jaggery",
    aliases: ["chini", "cheeni", "sugar"],
    packs: [{ size: 1, unit: "kg", price: 48, stockCount: 40 }],
  },
  {
    id: "coriander-leaves",
    name: "Coriander leaves",
    category: "Fresh vegetables",
    aliases: ["dhoniya pata", "dhone pata", "coriander", "cilantro", "kothimbir"],
    packs: [{ size: 100, unit: "g", price: 15, stockCount: 60 }],
  },
  {
    id: "potato",
    name: "Potato",
    category: "Fresh vegetables",
    aliases: ["aloo", "alu", "potato"],
    packs: [{ size: 1, unit: "kg", price: 35, stockCount: 200 }],
  },
  {
    id: "onion",
    name: "Onion",
    category: "Fresh vegetables",
    aliases: ["peyaj", "piyaj", "pyaz", "onion"],
    packs: [{ size: 1, unit: "kg", price: 42, stockCount: 200 }],
  },
  {
    id: "mustard-oil",
    name: "Kachi ghani mustard oil",
    category: "Edible oils",
    aliases: ["sorsher tel", "sorshe tel", "mustard oil", "sarson ka tel"],
    packs: [{ size: 1, unit: "l", price: 172, stockCount: 50 }],
  },
  {
    id: "masoor-dal",
    name: "Masoor dal, split red lentil",
    category: "Dals & pulses",
    aliases: ["musur dal", "moshur dal", "masoor dal", "red lentil"],
    packs: [{ size: 1, unit: "kg", price: 118, stockCount: 60 }],
  },
  {
    id: "turmeric-powder",
    name: "Turmeric powder",
    category: "Spices",
    aliases: ["haldi", "holud", "turmeric"],
    packs: [{ size: 200, unit: "g", price: 44, stockCount: 80 }],
  },
  {
    id: "nigella-seeds",
    name: "Nigella seeds (kalonji)",
    category: "Spices",
    aliases: ["kalo jeera", "kalonji", "nigella", "kalajeera"],
    packs: [{ size: 100, unit: "g", price: 38, stockCount: 70 }],
  },
  {
    id: "black-cumin",
    name: "Black cumin (shahi jeera)",
    category: "Spices",
    aliases: ["kala jeera", "shahi jeera", "black cumin", "kalo jeera"],
    packs: [{ size: 100, unit: "g", price: 120, stockCount: 30 }],
  },
  {
    id: "curd-set",
    name: "Curd, set",
    category: "Dairy",
    aliases: ["doi", "dahi", "curd", "yogurt"],
    // Only sold in 400 g tubs — a 500 g ask always rounds down to one tub.
    packs: [{ size: 400, unit: "g", price: 56, stockCount: 90 }],
  },
  {
    id: "green-chilli",
    name: "Green chilli",
    category: "Fresh vegetables",
    aliases: ["kacha lanka", "kacha morich", "hari mirch", "green chilli", "green chili"],
    packs: [{ size: 100, unit: "g", price: 18, stockCount: 90 }],
  },
  {
    id: "poppy-seeds",
    name: "Poppy seeds (posto)",
    category: "Spices",
    aliases: ["posto", "khus khus", "poppy seeds"],
    packs: [{ size: 100, unit: "g", price: 96, stockCount: 40 }],
  },
  {
    id: "gobindobhog-rice",
    name: "Gobindobhog rice",
    category: "Rice",
    aliases: ["chal", "chaal", "rice", "gobindobhog"],
    packs: [{ size: 5, unit: "kg", price: 540, stockCount: 40 }],
  },
  {
    id: "moong-dal",
    name: "Moong dal, split",
    category: "Dals & pulses",
    aliases: ["moong dal", "mug dal", "moog dal", "green gram dal"],
    packs: [{ size: 1, unit: "kg", price: 132, stockCount: 60 }],
  },
  {
    id: "panch-phoron",
    name: "Panch phoron spice mix",
    category: "Spices",
    aliases: ["panch phoron", "panch foron", "five spice"],
    packs: [{ size: 100, unit: "g", price: 45, stockCount: 50 }],
  },
  {
    id: "banana-robusta",
    name: "Banana, robusta",
    category: "Fresh fruit",
    aliases: ["kolar", "kola", "kela", "banana"],
    packs: [{ size: 12, unit: "pcs", price: 64, stockCount: 100 }],
  },
];

export function findItem(id: string): CatalogItem | undefined {
  return CATALOG.find((item) => item.id === id);
}

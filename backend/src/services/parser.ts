import Anthropic from "@anthropic-ai/sdk";

export interface ParsedItem {
  rawPhrase: string;
  itemQuery: string;
  requestedQty: number;
  requestedUnit: string;
}

export interface ParsedList {
  items: ParsedItem[];
  totalLines: number;
}

export interface ListParser {
  parse(rawText: string): Promise<ParsedList>;
}

function nonEmptyLines(rawText: string): string[] {
  return rawText
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
}

/**
 * Regex fallback used when there's no Anthropic API key configured. Handles
 * the common "<name> <qty> <unit>" shape without needing a model call, so
 * the whole app is testable offline.
 */
export class HeuristicListParser implements ListParser {
  private static readonly ITEM_LINE = /^(.*\D)\s+(\d+(?:\.\d+)?)\s*([a-zA-Z]+)\.?$/;

  async parse(rawText: string): Promise<ParsedList> {
    const lines = nonEmptyLines(rawText);
    const items: ParsedItem[] = [];
    for (const line of lines) {
      const match = line.match(HeuristicListParser.ITEM_LINE);
      if (!match) continue; // greetings / chatter — no trailing quantity, so skipped
      const [, name, qty, unit] = match;
      items.push({
        rawPhrase: line,
        itemQuery: name.trim(),
        requestedQty: Number(qty),
        requestedUnit: unit.trim(),
      });
    }
    return { items, totalLines: lines.length };
  }
}

const RECORD_ITEMS_TOOL: Anthropic.Tool = {
  name: "record_grocery_items",
  description: "Records the grocery items found in Ma's message, in the order she wrote them.",
  input_schema: {
    type: "object",
    properties: {
      items: {
        type: "array",
        items: {
          type: "object",
          properties: {
            rawPhrase: { type: "string", description: "The exact phrase Ma used for this item and quantity." },
            itemQuery: {
              type: "string",
              description:
                "Just the item name portion, in whatever language/script Ma wrote it (transliterated Bengali/Hindi is fine, keep it as-is — do not translate to English).",
            },
            requestedQty: { type: "number" },
            requestedUnit: { type: "string", description: "The unit exactly as written, e.g. kg, gm, litre, bundle, dozen." },
          },
          required: ["rawPhrase", "itemQuery", "requestedQty", "requestedUnit"],
        },
      },
    },
    required: ["items"],
  },
};

/**
 * Uses the Claude API to pull grocery items out of a pasted WhatsApp message
 * that mixes Bengali, Hindi and English (Hinglish/Banglish), skipping
 * greetings and instructions ("Babu ei list ta order kore dis").
 */
export class ClaudeListParser implements ListParser {
  private readonly client: Anthropic;

  constructor(apiKey: string) {
    this.client = new Anthropic({ apiKey });
  }

  async parse(rawText: string): Promise<ParsedList> {
    const message = await this.client.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 1024,
      system:
        "You extract a grocery shopping list from a message a mother sent her child over WhatsApp. " +
        "The message mixes Bengali, Hindi and English, sometimes transliterated. Skip greetings and " +
        "instructions that aren't items (e.g. 'Babu ei list ta order kore dis'). Call " +
        "record_grocery_items exactly once with every item found, preserving her wording.",
      tools: [RECORD_ITEMS_TOOL],
      tool_choice: { type: "tool", name: "record_grocery_items" },
      messages: [{ role: "user", content: rawText }],
    });

    const toolUse = message.content.find((block): block is Anthropic.ToolUseBlock => block.type === "tool_use");
    const items = ((toolUse?.input as { items?: ParsedItem[] } | undefined)?.items ?? []).map((item) => ({
      rawPhrase: item.rawPhrase,
      itemQuery: item.itemQuery,
      requestedQty: item.requestedQty,
      requestedUnit: item.requestedUnit,
    }));

    return { items, totalLines: nonEmptyLines(rawText).length };
  }
}

export function buildListParser(): ListParser {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (apiKey) return new ClaudeListParser(apiKey);
  console.warn("[parser] no ANTHROPIC_API_KEY set — using the regex HeuristicListParser instead of Claude");
  return new HeuristicListParser();
}

export const listParser: ListParser = buildListParser();

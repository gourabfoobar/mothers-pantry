import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const MCP_URL = process.env.KIRANA_MCP_URL ?? "http://localhost:4100/mcp";

let clientPromise: Promise<Client> | null = null;

async function connect(): Promise<Client> {
  const client = new Client({ name: "pantry-backend", version: "0.1.0" });
  const transport = new StreamableHTTPClientTransport(new URL(MCP_URL));
  await client.connect(transport);
  return client;
}

/** A single long-lived MCP session to kirana-now, reused across requests. */
async function getClient(): Promise<Client> {
  if (!clientPromise) {
    clientPromise = connect().catch((err) => {
      clientPromise = null;
      throw err;
    });
  }
  return clientPromise;
}

export interface McpToolResult<T> {
  ok: boolean;
  data?: T;
  error?: string;
}

export async function callKirana<T = unknown>(name: string, args: Record<string, unknown>): Promise<McpToolResult<T>> {
  try {
    const client = await getClient();
    const result = await client.callTool({ name, arguments: args });
    const content = (result.content as { type: string; text?: string }[] | undefined)?.[0];
    if (!content || content.type !== "text" || typeof content.text !== "string") {
      return { ok: false, error: "empty_response" };
    }
    const parsed = JSON.parse(content.text);
    if (parsed && typeof parsed === "object" && "error" in parsed) {
      return { ok: false, error: String((parsed as { error: unknown }).error) };
    }
    return { ok: true, data: parsed as T };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "mcp_call_failed" };
  }
}

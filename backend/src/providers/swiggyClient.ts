import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { SWIGGY_ORIGIN } from "./swiggyOAuth.js";

const INSTAMART_PATH = "/im";

const clientsByToken = new Map<string, Promise<Client>>();

async function connect(accessToken: string): Promise<Client> {
  const client = new Client({ name: "pantry-backend", version: "0.1.0" });
  const transport = new StreamableHTTPClientTransport(new URL(`${SWIGGY_ORIGIN}${INSTAMART_PATH}`), {
    requestInit: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
  await client.connect(transport);
  return client;
}

async function getClient(accessToken: string): Promise<Client> {
  let existing = clientsByToken.get(accessToken);
  if (!existing) {
    existing = connect(accessToken).catch((err) => {
      clientsByToken.delete(accessToken);
      throw err;
    });
    clientsByToken.set(accessToken, existing);
  }
  return existing;
}

export interface SwiggyEnvelope<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: { message: string; reportLink?: string; reportHint?: string };
}

/**
 * Calls a Swiggy Instamart MCP tool with this user's access token. Throws
 * on transport/auth failure; domain failures (`success: false`) are
 * returned to the caller per Swiggy's error-handling guidance — most are
 * terminal (out of stock, unserviceable) and shouldn't be retried blindly.
 */
export async function callSwiggyInstamart<T = unknown>(
  accessToken: string,
  name: string,
  args: Record<string, unknown>,
): Promise<SwiggyEnvelope<T>> {
  const client = await getClient(accessToken);
  const result = await client.callTool({ name, arguments: args });
  const content = (result.content as { type: string; text?: string }[] | undefined)?.[0];
  if (!content || content.type !== "text" || typeof content.text !== "string") {
    return { success: false, error: { message: "empty_response" } };
  }
  return JSON.parse(content.text) as SwiggyEnvelope<T>;
}

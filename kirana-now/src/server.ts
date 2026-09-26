import express from "express";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";
import { STORE_ID, STORE_NAME, STORE_PINCODE } from "./catalog.js";
import {
  searchProducts,
  getStock,
  createCart,
  getCart,
  setCartAddress,
  upsertCartLine,
  removeCartLine,
  cartTotal,
  placeOrder,
  getOrder,
} from "./store.js";

function textResult(payload: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(payload) }] };
}

function buildServer(): McpServer {
  const server = new McpServer({ name: "kirana-now", version: "0.1.0" });

  server.registerTool(
    "get_store",
    {
      title: "Get store",
      description: "Returns Kirana Now's store identity for this pincode — used once, at provider connect time.",
      inputSchema: {},
    },
    async () => textResult({ storeId: STORE_ID, name: STORE_NAME, pincode: STORE_PINCODE }),
  );

  server.registerTool(
    "search_products",
    {
      title: "Search products",
      description:
        "Finds catalogue items by name. Accepts Bengali/Hindi names transliterated into English as well as English names.",
      inputSchema: { query: z.string(), limit: z.number().int().min(1).max(20).optional() },
    },
    async ({ query, limit }) => textResult(searchProducts(query, limit)),
  );

  server.registerTool(
    "get_stock",
    {
      title: "Get stock",
      description: "Returns an item's pack sizes, prices, and how many packs of each are currently in stock.",
      inputSchema: { itemId: z.string() },
    },
    async ({ itemId }) => {
      const item = getStock(itemId);
      if (!item) return textResult({ error: "not_found", itemId });
      return textResult(item);
    },
  );

  server.registerTool(
    "create_cart",
    { title: "Create cart", description: "Starts a new, empty cart and returns its id.", inputSchema: {} },
    async () => textResult(createCart()),
  );

  server.registerTool(
    "set_cart_address",
    {
      title: "Set cart address",
      description: "Attaches a delivery address id to a cart, for a delivery-window and stock check.",
      inputSchema: { cartId: z.string(), addressId: z.string() },
    },
    async ({ cartId, addressId }) => {
      const cart = setCartAddress(cartId, addressId);
      if (!cart) return textResult({ error: "cart_not_found", cartId });
      return textResult(cart);
    },
  );

  server.registerTool(
    "update_cart_item",
    {
      title: "Update cart item",
      description:
        "Adds or updates a line in the cart for the requested quantity. Kirana Now always allocates packs " +
        "by rounding DOWN to the nearest amount it can actually fulfil from stock — never up. The response's " +
        "`roundedDown` flag tells you when the fulfilled quantity is less than what was requested.",
      inputSchema: { cartId: z.string(), itemId: z.string(), requestedQty: z.number().positive(), requestedUnit: z.string() },
    },
    async ({ cartId, itemId, requestedQty, requestedUnit }) => {
      const line = upsertCartLine(cartId, itemId, requestedQty, requestedUnit);
      if (!line) return textResult({ error: "cart_or_item_not_found", cartId, itemId });
      return textResult(line);
    },
  );

  server.registerTool(
    "remove_cart_item",
    {
      title: "Remove cart item",
      description: "Removes a line from the cart.",
      inputSchema: { cartId: z.string(), lineId: z.string() },
    },
    async ({ cartId, lineId }) => textResult({ removed: removeCartLine(cartId, lineId) }),
  );

  server.registerTool(
    "get_cart",
    {
      title: "Get cart",
      description: "Returns every line in the cart plus the running total.",
      inputSchema: { cartId: z.string() },
    },
    async ({ cartId }) => {
      const cart = getCart(cartId);
      if (!cart) return textResult({ error: "cart_not_found", cartId });
      return textResult({ ...cart, total: cartTotal(cart) });
    },
  );

  server.registerTool(
    "place_order",
    {
      title: "Place order",
      description: "Places the cart as an order. Only call this after the app's user has explicitly approved checkout.",
      inputSchema: { cartId: z.string() },
    },
    async ({ cartId }) => {
      const order = placeOrder(cartId);
      if (!order) return textResult({ error: "cart_empty_or_not_found", cartId });
      return textResult(order);
    },
  );

  server.registerTool(
    "get_order_status",
    {
      title: "Get order status",
      description:
        "Returns the order's current status (placed, packed, on_the_way, delivered), its event history, " +
        "and courier info while on the way. Poll this to drive Live Activity updates.",
      inputSchema: { orderId: z.string() },
    },
    async ({ orderId }) => {
      const order = getOrder(orderId);
      if (!order) return textResult({ error: "order_not_found", orderId });
      return textResult(order);
    },
  );

  return server;
}

const app = express();
app.use(express.json());

const transports = new Map<string, StreamableHTTPServerTransport>();

app.post("/mcp", async (req, res) => {
  const sessionId = req.header("mcp-session-id");
  let transport = sessionId ? transports.get(sessionId) : undefined;

  if (!transport && isInitializeRequest(req.body)) {
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (id) => {
        transports.set(id, transport!);
      },
    });
    transport.onclose = () => {
      if (transport!.sessionId) transports.delete(transport!.sessionId);
    };
    const server = buildServer();
    await server.connect(transport);
  }

  if (!transport) {
    res.status(400).json({ error: "no_session", message: "Missing or unknown mcp-session-id; send an initialize request first." });
    return;
  }

  await transport.handleRequest(req, res, req.body);
});

app.get("/mcp", async (req, res) => {
  const sessionId = req.header("mcp-session-id");
  const transport = sessionId ? transports.get(sessionId) : undefined;
  if (!transport) {
    res.status(400).send("Missing or unknown mcp-session-id");
    return;
  }
  await transport.handleRequest(req, res);
});

app.delete("/mcp", async (req, res) => {
  const sessionId = req.header("mcp-session-id");
  const transport = sessionId ? transports.get(sessionId) : undefined;
  if (!transport) {
    res.status(400).send("Missing or unknown mcp-session-id");
    return;
  }
  await transport.handleRequest(req, res);
});

app.get("/health", (_req, res) => res.json({ ok: true, store: STORE_NAME }));

const port = Number(process.env.PORT ?? 4100);
app.listen(port, () => {
  console.log(`kirana-now MCP server listening on http://localhost:${port}/mcp`);
});

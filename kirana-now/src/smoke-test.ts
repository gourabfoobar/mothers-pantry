import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

function parse(result: any) {
  return JSON.parse(result.content[0].text);
}

async function main() {
  const client = new Client({ name: "smoke-test", version: "0.0.1" });
  const transport = new StreamableHTTPClientTransport(new URL("http://localhost:4100/mcp"));
  await client.connect(transport);

  const tools = await client.listTools();
  console.log("tools:", tools.tools.map((t) => t.name).join(", "));

  const search = parse(await client.callTool({ name: "search_products", arguments: { query: "kalo jeera" } }));
  console.log("search 'kalo jeera' ->", search);

  const cart = parse(await client.callTool({ name: "create_cart", arguments: {} }));
  console.log("cart created:", cart.id);

  const attaLine = parse(
    await client.callTool({
      name: "update_cart_item",
      arguments: { cartId: cart.id, itemId: "atta-whole-wheat", requestedQty: 5, requestedUnit: "kg" },
    }),
  );
  console.log("atta 5kg requested ->", attaLine.allocation);
  if (!attaLine.allocation.roundedDown || attaLine.allocation.fulfilledQty !== 4) {
    throw new Error("expected atta to round down to 4kg");
  }

  const curdLine = parse(
    await client.callTool({
      name: "update_cart_item",
      arguments: { cartId: cart.id, itemId: "curd-set", requestedQty: 500, requestedUnit: "g" },
    }),
  );
  console.log("curd 500g requested ->", curdLine.allocation);
  if (curdLine.allocation.fulfilledQty !== 400) {
    throw new Error("expected curd to round down to 400g");
  }

  const gotCart = parse(await client.callTool({ name: "get_cart", arguments: { cartId: cart.id } }));
  console.log("cart total ->", gotCart.total);

  const order = parse(await client.callTool({ name: "place_order", arguments: { cartId: cart.id } }));
  console.log("order placed ->", order.id, order.status);

  await new Promise((r) => setTimeout(r, 16_000));
  const status = parse(await client.callTool({ name: "get_order_status", arguments: { orderId: order.id } }));
  console.log("order status after 16s ->", status.status, status.events);

  console.log("SMOKE TEST PASSED");
  process.exit(0);
}

main().catch((err) => {
  console.error("SMOKE TEST FAILED", err);
  process.exit(1);
});

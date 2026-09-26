# Kirana Now (mock)

A local grocery provider that speaks real MCP (Streamable HTTP transport) so the
`backend` service can be exercised end to end without any external account.

## Run

```
npm install
npm run dev        # tsx watch, http://localhost:4100/mcp
```

or `npm run build && npm start` for the compiled version. `npm run smoke` drives
a full cart → round-down → order → status flow against a running server.

## Tools

`get_store`, `search_products`, `get_stock`, `create_cart`, `set_cart_address`,
`update_cart_item`, `remove_cart_item`, `get_cart`, `place_order`, `get_order_status`.

## The round-down rule

`update_cart_item` allocates the requested quantity from the largest in-stock
pack down, and never exceeds the request. `src/catalog.ts` seeds two cases that
exercise this on purpose:

- **Atta**: no 1 kg or 5 kg packs in stock, only two 2 kg packs — a request for
  5 kg always resolves to 4 kg (`roundedDown: true`).
- **Curd**: only sold in 400 g tubs — a request for 500 g always resolves to
  400 g.

Every other item in the catalogue matches an item from Ma's sample list on the
design canvas (aloo, peyaj, sorsher tel, musur dal, haldi, kalo jeera, doi,
kacha lanka, posto, chal, moong dal, panch phoron, kolar…), including the
`kalo jeera` alias collision between nigella seeds and black cumin that the
Review/Approve-a-match screens are built around.

Order status progresses `placed → packed → on_the_way → delivered` on a timer
(`KIRANA_STAGE_DELAY_MS`, default 15s per stage) so the backend's poller has
something to push as Live Activity updates during local testing.

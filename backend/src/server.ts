import "dotenv/config";
import express from "express";
import cors from "cors";
import { authRouter } from "./routes/auth.js";
import { providersRouter } from "./routes/providers.js";
import { recipientsRouter } from "./routes/recipients.js";
import { addressesRouter } from "./routes/addresses.js";
import { devicesRouter } from "./routes/devices.js";
import { listsRouter } from "./routes/lists.js";
import { matchesRouter, qtyRouter } from "./routes/matches.js";
import { ordersRouter } from "./routes/orders.js";
import { startOrderPoller } from "./services/orderPoller.js";

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => res.json({ ok: true }));

app.use("/auth", authRouter);
app.use("/providers", providersRouter);
app.use("/recipients", recipientsRouter);
app.use("/addresses", addressesRouter);
app.use("/devices", devicesRouter);
app.use("/lists", listsRouter);
app.use("/matches", matchesRouter);
app.use("/qty", qtyRouter);
app.use("/orders", ordersRouter);

startOrderPoller();

const port = Number(process.env.PORT ?? 4200);
app.listen(port, () => {
  console.log(`pantry-backend listening on http://localhost:${port}`);
});

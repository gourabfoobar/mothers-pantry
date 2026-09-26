import "dotenv/config";
import express from "express";
import cors from "cors";
import { authRouter } from "./routes/auth.js";
import { providersRouter } from "./routes/providers.js";
import { recipientsRouter } from "./routes/recipients.js";
import { addressesRouter } from "./routes/addresses.js";
import { devicesRouter } from "./routes/devices.js";

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => res.json({ ok: true }));

app.use("/auth", authRouter);
app.use("/providers", providersRouter);
app.use("/recipients", recipientsRouter);
app.use("/addresses", addressesRouter);
app.use("/devices", devicesRouter);

const port = Number(process.env.PORT ?? 4200);
app.listen(port, () => {
  console.log(`pantry-backend listening on http://localhost:${port}`);
});

import { Router } from "express";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";

export const recipientsRouter = Router();

recipientsRouter.get("/", requireAuth, (req: AuthedRequest, res) => {
  const rows = db
    .prepare("SELECT id, name, relation, phone, may_call as mayCall FROM recipients WHERE user_id = ? ORDER BY created_at")
    .all(req.userId!) as { mayCall: number }[];
  res.json(rows.map((row) => ({ ...row, mayCall: Boolean(row.mayCall) })));
});

const createSchema = z.object({
  name: z.string().min(1),
  relation: z.string().optional(),
  phone: z.string().optional(),
  mayCall: z.boolean().optional(),
});

recipientsRouter.post("/", requireAuth, (req: AuthedRequest, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", details: parsed.error.flatten() });
    return;
  }
  const { name, relation, phone, mayCall } = parsed.data;
  const id = randomUUID();
  db.prepare(
    "INSERT INTO recipients (id, user_id, name, relation, phone, may_call, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
  ).run(id, req.userId!, name, relation ?? null, phone ?? null, mayCall === false ? 0 : 1, new Date().toISOString());
  res.status(201).json({ id, name, relation, phone, mayCall: mayCall !== false });
});

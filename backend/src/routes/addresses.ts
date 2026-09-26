import { Router } from "express";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";

export const addressesRouter = Router();

addressesRouter.get("/", requireAuth, (req: AuthedRequest, res) => {
  const rows = db
    .prepare(
      `SELECT id, recipient_id as recipientId, label, line1, city, pincode
       FROM addresses WHERE user_id = ? ORDER BY created_at`,
    )
    .all(req.userId!);
  res.json(rows);
});

const createSchema = z.object({
  recipientId: z.string().optional(),
  label: z.string().min(1),
  line1: z.string().min(1),
  city: z.string().optional(),
  pincode: z.string().optional(),
});

addressesRouter.post("/", requireAuth, (req: AuthedRequest, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", details: parsed.error.flatten() });
    return;
  }
  const { recipientId, label, line1, city, pincode } = parsed.data;
  const id = randomUUID();
  db.prepare(
    `INSERT INTO addresses (id, user_id, recipient_id, label, line1, city, pincode, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, req.userId!, recipientId ?? null, label, line1, city ?? null, pincode ?? null, new Date().toISOString());
  res.status(201).json({ id, recipientId, label, line1, city, pincode });
});

import { Router } from "express";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";

export const devicesRouter = Router();

const registerSchema = z.object({
  pushToken: z.string().optional(),
  activityPushToStartToken: z.string().optional(),
});

/** Called after notification/Live-Activity permission is granted (canvas 1.4). */
devicesRouter.post("/register", requireAuth, (req: AuthedRequest, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request" });
    return;
  }
  const { pushToken, activityPushToStartToken } = parsed.data;
  const id = randomUUID();
  db.prepare(
    `INSERT INTO devices (id, user_id, push_token, activity_push_to_start_token, registered_at)
     VALUES (?, ?, ?, ?, ?)`,
  ).run(id, req.userId, pushToken ?? null, activityPushToStartToken ?? null, new Date().toISOString());
  res.status(201).json({ id });
});

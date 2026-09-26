import { Router } from "express";
import { randomUUID, randomInt } from "node:crypto";
import { z } from "zod";
import { db } from "../db/index.js";
import { smsProvider } from "../services/sms.js";
import { signToken, requireAuth, type AuthedRequest } from "../services/auth.js";

export const authRouter = Router();

const OTP_TTL_MS = 5 * 60 * 1000;

const requestSchema = z.object({ phone: z.string().min(6) });

authRouter.post("/otp/request", async (req, res) => {
  const parsed = requestSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_phone" });
    return;
  }
  const { phone } = parsed.data;
  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString();

  db.prepare(
    `INSERT INTO otp_codes (phone, code, expires_at, attempts) VALUES (?, ?, ?, 0)
     ON CONFLICT(phone) DO UPDATE SET code = excluded.code, expires_at = excluded.expires_at, attempts = 0`,
  ).run(phone, code, expiresAt);

  await smsProvider.send(phone, `Your Mother's Pantry code is ${code}. It expires in 5 minutes.`);

  const isDev = process.env.NODE_ENV !== "production";
  res.json({ sent: true, ...(isDev ? { devCode: code } : {}) });
});

const verifySchema = z.object({ phone: z.string().min(6), code: z.string().length(6) });

authRouter.post("/otp/verify", (req, res) => {
  const parsed = verifySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request" });
    return;
  }
  const { phone, code } = parsed.data;

  const row = db.prepare("SELECT code, expires_at, attempts FROM otp_codes WHERE phone = ?").get(phone) as
    | { code: string; expires_at: string; attempts: number }
    | undefined;

  if (!row || new Date(row.expires_at).getTime() < Date.now()) {
    res.status(400).json({ error: "expired_or_not_requested" });
    return;
  }
  if (row.attempts >= 5) {
    res.status(429).json({ error: "too_many_attempts" });
    return;
  }
  if (row.code !== code) {
    db.prepare("UPDATE otp_codes SET attempts = attempts + 1 WHERE phone = ?").run(phone);
    res.status(400).json({ error: "incorrect_code" });
    return;
  }

  db.prepare("DELETE FROM otp_codes WHERE phone = ?").run(phone);

  const existing = db.prepare("SELECT id FROM users WHERE phone = ?").get(phone) as { id: string } | undefined;
  const isNewUser = !existing;
  const userId = existing?.id ?? randomUUID();
  if (isNewUser) {
    db.prepare("INSERT INTO users (id, phone, created_at) VALUES (?, ?, ?)").run(
      userId,
      phone,
      new Date().toISOString(),
    );
  }

  res.json({ token: signToken(userId), userId, isNewUser });
});

const profileSchema = z.object({
  name: z.string().min(1),
  email: z.string().email().optional(),
  notificationsEnabled: z.boolean().optional(),
});

authRouter.post("/profile", requireAuth, (req: AuthedRequest, res) => {
  const parsed = profileSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", details: parsed.error.flatten() });
    return;
  }
  const { name, email, notificationsEnabled } = parsed.data;
  db.prepare("UPDATE users SET name = ?, email = ?, notifications_enabled = ? WHERE id = ?").run(
    name,
    email ?? null,
    notificationsEnabled === false ? 0 : 1,
    req.userId!,
  );
  const user = db.prepare("SELECT id, phone, name, email, notifications_enabled FROM users WHERE id = ?").get(
    req.userId!,
  );
  res.json(user);
});

authRouter.get("/me", requireAuth, (req: AuthedRequest, res) => {
  const user = db.prepare("SELECT id, phone, name, email, notifications_enabled FROM users WHERE id = ?").get(
    req.userId!,
  );
  if (!user) {
    res.status(404).json({ error: "not_found" });
    return;
  }
  res.json(user);
});

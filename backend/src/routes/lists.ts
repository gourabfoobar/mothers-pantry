import { Router } from "express";
import { z } from "zod";
import { db } from "../db/index.js";
import { requireAuth, type AuthedRequest } from "../services/auth.js";
import { createList, matchList, buildReview } from "../services/listService.js";
import { notifyNeedsApproval } from "../services/notifications.js";

export const listsRouter = Router();

const createSchema = z.object({ addressId: z.string().min(1), rawText: z.string().min(1) });

listsRouter.post("/", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", details: parsed.error.flatten() });
    return;
  }
  const { addressId, rawText } = parsed.data;

  const address = db.prepare("SELECT id FROM addresses WHERE id = ? AND user_id = ?").get(addressId, req.userId!);
  if (!address) {
    res.status(404).json({ error: "address_not_found" });
    return;
  }

  try {
    const created = await createList(req.userId!, addressId, rawText);
    res.status(201).json({ ...created, languages: ["Bengali", "Hindi", "English"] });
  } catch (err) {
    res.status(502).json({ error: "provider_unreachable", detail: err instanceof Error ? err.message : String(err) });
  }
});

function loadList(listId: string, userId: string) {
  return db.prepare("SELECT id FROM grocery_lists WHERE id = ? AND user_id = ?").get(listId, userId) as
    | { id: string }
    | undefined;
}

listsRouter.post("/:id/match", requireAuth, async (req: AuthedRequest, res) => {
  const list = loadList(req.params.id, req.userId!);
  if (!list) {
    res.status(404).json({ error: "list_not_found" });
    return;
  }
  await matchList(list.id);
  notifyNeedsApproval(list.id).catch((err) => console.error("[notify] failed", err));
  res.json(buildReview(list.id));
});

listsRouter.get("/:id/review", requireAuth, (req: AuthedRequest, res) => {
  const list = loadList(req.params.id, req.userId!);
  if (!list) {
    res.status(404).json({ error: "list_not_found" });
    return;
  }
  res.json(buildReview(list.id));
});

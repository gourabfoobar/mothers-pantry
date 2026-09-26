import Database from "better-sqlite3";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const dbPath = process.env.PANTRY_DB_PATH ?? path.join(__dirname, "..", "..", "pantry.sqlite");
export const db = new Database(dbPath);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

const schema = readFileSync(path.join(__dirname, "schema.sql"), "utf8");
db.exec(schema);

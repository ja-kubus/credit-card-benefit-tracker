import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { config } from './config';
import type { EncryptedToken } from './crypto';

/**
 * SQLite datastore (single file).
 *
 * Tables:
 *  - users(id TEXT PK = Apple `sub`, created_at)
 *  - links(id, user_id, institution, enrollment_id,
 *          token_ciphertext, token_iv, token_tag, created_at)
 *
 * There is NO transactions table by design: transactions are never persisted
 * server-side. They are fetched live from Teller, normalized, and returned to
 * the app, which stores them on-device only.
 */

// Ensure the parent directory exists.
const dir = path.dirname(config.databasePath);
if (dir && dir !== '.' && !fs.existsSync(dir)) {
  fs.mkdirSync(dir, { recursive: true });
}

export const db = new Database(config.databasePath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id          TEXT PRIMARY KEY,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS links (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL,
    institution       TEXT,
    enrollment_id     TEXT,
    token_ciphertext  BLOB NOT NULL,
    token_iv          BLOB NOT NULL,
    token_tag         BLOB NOT NULL,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_links_user ON links(user_id);
`);

// ---- Prepared statements ----

const stmtUpsertUser = db.prepare(
  `INSERT INTO users (id) VALUES (?) ON CONFLICT(id) DO NOTHING`,
);

const stmtInsertLink = db.prepare(
  `INSERT INTO links
     (id, user_id, institution, enrollment_id, token_ciphertext, token_iv, token_tag)
   VALUES
     (@id, @userId, @institution, @enrollmentId, @ciphertext, @iv, @tag)`,
);

const stmtLinksForUser = db.prepare(
  `SELECT id, user_id AS userId, institution, enrollment_id AS enrollmentId,
          token_ciphertext AS ciphertext, token_iv AS iv, token_tag AS tag,
          created_at AS createdAt
     FROM links WHERE user_id = ?`,
);

const stmtDeleteLink = db.prepare(
  `DELETE FROM links WHERE id = ? AND user_id = ?`,
);

// ---- Types ----

export interface LinkRow {
  id: string;
  userId: string;
  institution: string | null;
  enrollmentId: string | null;
  createdAt: string;
  token: EncryptedToken;
}

interface RawLinkRow {
  id: string;
  userId: string;
  institution: string | null;
  enrollmentId: string | null;
  ciphertext: Buffer;
  iv: Buffer;
  tag: Buffer;
  createdAt: string;
}

function toLinkRow(r: RawLinkRow): LinkRow {
  return {
    id: r.id,
    userId: r.userId,
    institution: r.institution,
    enrollmentId: r.enrollmentId,
    createdAt: r.createdAt,
    token: { ciphertext: r.ciphertext, iv: r.iv, tag: r.tag },
  };
}

// ---- Public API ----

export function upsertUser(id: string): void {
  stmtUpsertUser.run(id);
}

export function insertLink(params: {
  id: string;
  userId: string;
  institution: string | null;
  enrollmentId: string | null;
  token: EncryptedToken;
}): void {
  stmtInsertLink.run({
    id: params.id,
    userId: params.userId,
    institution: params.institution,
    enrollmentId: params.enrollmentId,
    ciphertext: params.token.ciphertext,
    iv: params.token.iv,
    tag: params.token.tag,
  });
}

export function getLinksForUser(userId: string): LinkRow[] {
  const rows = stmtLinksForUser.all(userId) as RawLinkRow[];
  return rows.map(toLinkRow);
}

/** Returns true if a row was deleted (i.e. the link belonged to the user). */
export function deleteLink(linkId: string, userId: string): boolean {
  const info = stmtDeleteLink.run(linkId, userId);
  return info.changes > 0;
}

import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { config } from './config';

/**
 * SQLite datastore (single file).
 *
 * Tables:
 *  - users(id TEXT PK = Apple `sub`, stripe_customer_id, created_at)
 *  - accounts(id TEXT PK = Stripe FC account id, user_id, institution,
 *             display_name, last4, refresh_cursor, created_at)
 *
 * There is NO transactions table by design: transactions are never persisted
 * server-side. They are fetched live from Stripe, normalized, and returned to
 * the app, which stores them on-device only.
 *
 * There is NOTHING SECRET in this database: a Stripe customer id and FC account
 * ids are useless without the server's Stripe secret key (held only in env).
 * Unlike the prior Teller design, there are no encrypted access tokens here.
 */

const dir = path.dirname(config.databasePath);
if (dir && dir !== '.' && !fs.existsSync(dir)) {
  fs.mkdirSync(dir, { recursive: true });
}

export const db = new Database(config.databasePath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id                  TEXT PRIMARY KEY,
    stripe_customer_id  TEXT,
    created_at          TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS accounts (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL,
    institution     TEXT,
    display_name    TEXT,
    last4           TEXT,
    refresh_cursor  TEXT,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts(user_id);
`);

// ---- Prepared statements ----

const stmtUpsertUser = db.prepare(
  `INSERT INTO users (id) VALUES (?) ON CONFLICT(id) DO NOTHING`,
);

const stmtGetUser = db.prepare(
  `SELECT id, stripe_customer_id AS stripeCustomerId FROM users WHERE id = ?`,
);

const stmtSetCustomerId = db.prepare(
  `UPDATE users SET stripe_customer_id = ? WHERE id = ?`,
);

const stmtUpsertAccount = db.prepare(
  `INSERT INTO accounts (id, user_id, institution, display_name, last4)
     VALUES (@id, @userId, @institution, @displayName, @last4)
   ON CONFLICT(id) DO UPDATE SET
     institution  = excluded.institution,
     display_name = excluded.display_name,
     last4        = excluded.last4`,
);

const stmtAccountsForUser = db.prepare(
  `SELECT id, user_id AS userId, institution, display_name AS displayName,
          last4, refresh_cursor AS refreshCursor, created_at AS createdAt
     FROM accounts WHERE user_id = ?`,
);

const stmtSetRefreshCursor = db.prepare(
  `UPDATE accounts SET refresh_cursor = ? WHERE id = ? AND user_id = ?`,
);

const stmtDeleteAccount = db.prepare(
  `DELETE FROM accounts WHERE id = ? AND user_id = ?`,
);

const stmtOwnsAccount = db.prepare(
  `SELECT 1 FROM accounts WHERE id = ? AND user_id = ?`,
);

// ---- Types ----

export interface UserRow {
  id: string;
  stripeCustomerId: string | null;
}

export interface AccountRow {
  id: string;
  userId: string;
  institution: string | null;
  displayName: string | null;
  last4: string | null;
  refreshCursor: string | null;
  createdAt: string;
}

// ---- Public API ----

export function upsertUser(id: string): void {
  stmtUpsertUser.run(id);
}

export function getUser(id: string): UserRow | undefined {
  return stmtGetUser.get(id) as UserRow | undefined;
}

export function setCustomerId(userId: string, customerId: string): void {
  stmtSetCustomerId.run(customerId, userId);
}

export function upsertAccount(params: {
  id: string;
  userId: string;
  institution: string | null;
  displayName: string | null;
  last4: string | null;
}): void {
  stmtUpsertAccount.run(params);
}

export function getAccountsForUser(userId: string): AccountRow[] {
  return stmtAccountsForUser.all(userId) as AccountRow[];
}

export function setRefreshCursor(
  accountId: string,
  userId: string,
  cursor: string,
): void {
  stmtSetRefreshCursor.run(cursor, accountId, userId);
}

/** Returns true if a row was deleted (i.e. the account belonged to the user). */
export function deleteAccount(accountId: string, userId: string): boolean {
  const info = stmtDeleteAccount.run(accountId, userId);
  return info.changes > 0;
}

export function userOwnsAccount(accountId: string, userId: string): boolean {
  return stmtOwnsAccount.get(accountId, userId) !== undefined;
}

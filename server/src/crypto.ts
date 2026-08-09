import crypto from 'node:crypto';
import { config } from './config';

/**
 * AES-256-GCM helpers for encrypting Teller access tokens at rest.
 *
 * We store three columns per token: ciphertext, iv (nonce), and auth tag.
 * The 32-byte key comes from config.masterKey (env MASTER_KEY, base64).
 *
 * SECURITY:
 *  - A fresh random 12-byte IV is generated for every encryption. Never reuse
 *    an (key, iv) pair with GCM.
 *  - The GCM auth tag is verified on decrypt; tampering throws.
 *  - Plaintext tokens are never persisted or logged.
 */

const ALGO = 'aes-256-gcm';
const IV_LENGTH = 12; // 96-bit nonce, recommended for GCM

export interface EncryptedToken {
  ciphertext: Buffer;
  iv: Buffer;
  tag: Buffer;
}

export function encryptToken(plaintext: string): EncryptedToken {
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGO, config.masterKey, iv);
  const ciphertext = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return { ciphertext, iv, tag };
}

export function decryptToken(enc: EncryptedToken): string {
  const decipher = crypto.createDecipheriv(ALGO, config.masterKey, enc.iv);
  decipher.setAuthTag(enc.tag);
  const plaintext = Buffer.concat([
    decipher.update(enc.ciphertext),
    decipher.final(),
  ]);
  return plaintext.toString('utf8');
}

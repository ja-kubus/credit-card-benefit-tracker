import { createRemoteJWKSet, jwtVerify } from 'jose';
import { config } from './config';

/**
 * Sign in with Apple identity-token verification.
 *
 * Verifies:
 *  - signature against Apple's published JWKS (fetched + cached by `jose`)
 *  - iss === https://appleid.apple.com
 *  - aud === APPLE_CLIENT_ID (your bundle id / Services ID)
 *  - exp (handled by jwtVerify)
 *
 * Returns the stable user id (`sub`). We do NOT trust or persist email/name
 * from the token here — only the immutable `sub` is used as our user id.
 */

// createRemoteJWKSet caches keys and refreshes on rotation / unknown kid.
const jwks = createRemoteJWKSet(new URL(config.appleKeysUrl), {
  cacheMaxAge: 24 * 60 * 60 * 1000, // 24h
});

export interface AppleIdentity {
  sub: string;
}

export async function verifyAppleIdentityToken(
  identityToken: string,
): Promise<AppleIdentity> {
  const { payload } = await jwtVerify(identityToken, jwks, {
    issuer: config.appleIssuer,
    audience: config.appleClientId,
  });

  const sub = payload.sub;
  if (!sub || typeof sub !== 'string') {
    throw new Error('Apple token missing sub');
  }

  return { sub };
}

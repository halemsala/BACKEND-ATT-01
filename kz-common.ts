import crypto from 'node:crypto';
import { z } from 'zod';
import type { Principal } from '../contracts.js';
import type { SqlExecutor } from '../database.js';
import { DomainError } from '../errors.js';
import { writeAuditEvent } from '../audit-events.js';

export const uuid = z.uuid();
export const version = z.number().int().positive();
export const idempotencyKey = z.string().trim().min(1).max(120);
export const shortText = z.string().trim().min(1).max(500);
export const optionalNotes = z.string().trim().max(2000).optional();
export const cents = z.number().int().nonnegative();
export const positiveCents = z.number().int().positive();
export const isoDatetime = z.iso.datetime({ offset: true });

export function requireHuman(
  p: Principal,
  method: 'GET' | 'POST' | 'PUT' | 'PATCH',
  _path: string,
): void {
  if (!p.workspaceId || !p.actorId) {
    throw new DomainError('FORBIDDEN', 403);
  }
  if (p.role === 'agent') {
    throw new DomainError('FORBIDDEN', 403);
  }
  if (method !== 'GET' && p.role !== 'operator' && p.role !== 'admin') {
    throw new DomainError('FORBIDDEN', 403);
  }
}

export function sameVersion(row: { version: number }, expectedVersion: number): void {
  if (row.version !== expectedVersion) {
    throw new DomainError('VERSION_CONFLICT', 409);
  }
}

export async function ready(
  tx: SqlExecutor,
  tableName: string,
  moduleCode: string,
): Promise<void> {
  const res = await tx.query<{ reg: string | null }>(
    'SELECT to_regclass($1)::text AS reg',
    [tableName],
  );
  if (!res.rows[0]?.reg) {
    throw new DomainError(`${moduleCode.toUpperCase()}_MIGRATION_REQUIRED`, 503);
  }
}

export async function audit(
  tx: SqlExecutor,
  p: Principal,
  action: string,
  entityId: string,
  payload?: Record<string, unknown>,
  category = 'kz',
): Promise<void> {
  await writeAuditEvent(tx, {
    workspaceId: p.workspaceId,
    actorId: p.actorId,
    action,
    entityId,
    payload,
    category,
  });
}

export function setSensitiveResponseHeaders(res?: {
  setHeader: (name: string, value: string) => void;
}): void {
  if (!res) return;
  res.setHeader('Cache-Control', 'private, no-store');
  res.setHeader('Vary', 'Authorization, Cookie');
}

function resolveSecretMaterial(): string {
  const secret =
    process.env.KAZZUS_KZ_FIELD_KEY || process.env.KAZZUS_SESSION_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === 'production') {
      throw new DomainError('FIELD_ENCRYPTION_KEY_REQUIRED', 500);
    }
    return 'kazzus-local-dev-only-key-material';
  }
  return secret;
}

function resolveEncryptionKey(version: 'v1' | 'v2' = 'v1'): Buffer {
  if (version === 'v2') {
    const v2Secret = process.env.KAZZUS_KZ_FIELD_KEY_V2;
    if (v2Secret) {
      return crypto.createHash('sha256').update(v2Secret).digest();
    }
    return crypto.createHash('sha256').update(`${resolveSecretMaterial()}::v2`).digest();
  }
  return crypto.createHash('sha256').update(resolveSecretMaterial()).digest();
}

export function getActiveEncryptionVersion(): 'v1' | 'v2' {
  if (
    process.env.KAZZUS_KZ_FIELD_KEY_VERSION === 'v2' ||
    Boolean(process.env.KAZZUS_KZ_FIELD_KEY_V2)
  ) {
    return 'v2';
  }
  return 'v1';
}

export function encryptSensitiveField(plaintext: string): string {
  const keyVer = getActiveEncryptionVersion();
  const key = resolveEncryptionKey(keyVer);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${keyVer}:${iv.toString('base64')}:${tag.toString('base64')}:${encrypted.toString('base64')}`;
}

export function decryptSensitiveField(ciphertext: string): string {
  const parts = ciphertext.split(':');
  const keyVer = parts[0] === 'v2' ? 'v2' : parts[0] === 'v1' ? 'v1' : null;
  if (parts.length !== 4 || !keyVer) {
    throw new DomainError('INVALID_CIPHERTEXT', 500);
  }
  const [, ivB64, tagB64, dataB64] = parts;
  const key = resolveEncryptionKey(keyVer);
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    key,
    Buffer.from(ivB64, 'base64'),
  );
  decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(dataB64, 'base64')),
    decipher.final(),
  ]);
  return decrypted.toString('utf8');
}

export function computeHmacSignature(payload: string): string {
  const hmacKey =
    process.env.KAZZUS_KZ_HMAC_SECRET || `${resolveSecretMaterial()}::hmac`;
  return crypto.createHmac('sha256', hmacKey).update(payload).digest('hex');
}

export function verifyHmacSignature(payload: string, expectedHex: string): boolean {
  const computed = Buffer.from(computeHmacSignature(payload), 'hex');
  const provided = Buffer.from(expectedHex, 'hex');
  if (computed.length !== provided.length) return false;
  return crypto.timingSafeEqual(computed, provided);
}

function hashInt32(input: string): number {
  let h = 2166136261;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h | 0;
}

export async function tryAcquireWorkspaceAdvisoryLock(
  tx: SqlExecutor,
  workspaceId: string,
  lockNamespace: string,
): Promise<boolean> {
  const k1 = hashInt32(workspaceId);
  const k2 = hashInt32(lockNamespace);
  try {
    const res = await tx.query<{ locked: boolean }>(
      'SELECT pg_try_advisory_xact_lock($1::int, $2::int) AS locked',
      [k1, k2],
    );
    return res.rows[0]?.locked !== false;
  } catch {
    // Graceful fallback when running against minimal mock/SQLite drivers without pg_try_advisory_xact_lock
    return true;
  }
}

export function hashPinScrypt(pin: string, saltHex?: string): { hash: string; salt: string } {
  const salt = saltHex || crypto.randomBytes(16).toString('hex');
  const derived = crypto.scryptSync(pin, salt, 64).toString('hex');
  return { hash: derived, salt };
}

export function verifyPinScrypt(pin: string, salt: string, expectedHash: string): boolean {
  const derived = crypto.scryptSync(pin, salt, 64);
  const expected = Buffer.from(expectedHash, 'hex');
  if (derived.length !== expected.length) return false;
  return crypto.timingSafeEqual(derived, expected);
}

export async function hasTable(tx: SqlExecutor, tableName: string): Promise<boolean> {
  const res = await tx.query<{ reg: string | null }>(
    'SELECT to_regclass($1)::text AS reg',
    [tableName],
  );
  return Boolean(res.rows[0]?.reg);
}

export async function assertRecentStepUpGrant(
  tx: SqlExecutor,
  p: Principal,
  scope: string,
): Promise<string> {
  await ready(tx, 'crm.kz_stepup_grants', 'KZ_SEGURANCA');
  const row = (
    await tx.query<{ id: string }>(
      `SELECT id FROM crm.kz_stepup_grants
       WHERE workspace_id=$1 AND actor_id=$2 AND scope=$3
         AND expires_at > now() AND archived_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
      [p.workspaceId, p.actorId, scope],
    )
  ).rows[0];
  if (!row) {
    throw new DomainError('STEPUP_GRANT_REQUIRED', 403);
  }
  return row.id;
}

export function hasProductionFieldKeyConfigured(): boolean {
  return Boolean(
    process.env.KAZZUS_KZ_FIELD_KEY ||
      process.env.KAZZUS_KZ_FIELD_KEY_V2 ||
      process.env.KAZZUS_SESSION_SECRET,
  );
}

const SENSITIVE_KEY_RE =
  /(passcode|pin|password|secret|token|cpf|cnpj|rg|cipher|encrypted|auth_tag|private_key)/i;

export function redactPiiText(input: string): string {
  return input
    .replace(/\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/g, '[CPF_REDACTED]')
    .replace(/\b\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}\b/g, '[CNPJ_REDACTED]')
    .replace(/(?:\+55\s?)?\(?\d{2}\)?\s?9?\d{4}-?\d{4}\b/g, '[PHONE_REDACTED]')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[EMAIL_REDACTED]')
    .replace(/v[12]:[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+/g, '[CIPHERTEXT_REDACTED]')
    .replace(/\bBearer\s+[A-Za-z0-9._-]{12,}/gi, 'Bearer [TOKEN_REDACTED]');
}

export function redactSensitiveObject(value: unknown, depth = 0): unknown {
  if (depth > 8 || value === null || value === undefined) return value;
  if (typeof value === 'string') return redactPiiText(value);
  if (Array.isArray(value)) return value.map((item) => redactSensitiveObject(item, depth + 1));
  if (typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = SENSITIVE_KEY_RE.test(k) ? '[REDACTED]' : redactSensitiveObject(v, depth + 1);
    }
    return out;
  }
  return value;
}

export function sanitizeErrorMessage(err: unknown): string {
  const raw = err instanceof Error ? err.message : String(err ?? 'INTERNAL_ERROR');
  const stripped = redactPiiText(raw)
    .replace(/[A-Za-z]:\\[^\s'"]+/g, '[PATH_REDACTED]')
    .replace(/\/(?:app|src|home|tmp|var|etc|usr)\/[^\s'"]+/g, '[PATH_REDACTED]')
    .replace(/\b(?:SELECT|INSERT|UPDATE|DELETE|FROM|JOIN|WHERE)\b[\s\S]{0,160}/gi, '[SQL_REDACTED]')
    .replace(/\s+/g, ' ')
    .trim();
  return (stripped || 'INTERNAL_ERROR').slice(0, 240);
}

export function assertSafePathRef(ref: string): string {
  const trimmed = ref.trim();
  if (
    !trimmed ||
    trimmed.includes('\0') ||
    trimmed.includes('..') ||
    trimmed.startsWith('\\\\') ||
    /[`$;|&<>]/.test(trimmed)
  ) {
    throw new DomainError('INVALID_PATH_REFERENCE', 422);
  }
  return trimmed;
}

export function maskDisplayName(name: string): string {
  const clean = name.trim();
  if (clean.length <= 2) return '***';
  return `${clean.slice(0, 2)}***${clean.slice(-1)}`;
}

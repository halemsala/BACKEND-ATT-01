import { z } from 'zod';
import { idempotencyKey, isoDatetime, positiveCents, version } from '../kz-common.js';

export const createStoreCreditSchema = z
  .object({
    customer_id: z.uuid(),
    return_case_id: z.uuid().optional(),
    initial_cents: positiveCents,
    expires_at: isoDatetime.optional(),
    idempotency_key: idempotencyKey,
  })
  .strict();

export const useStoreCreditSchema = z
  .object({
    amount_cents: positiveCents,
    order_id: z.uuid(),
    expected_version: version,
    idempotency_key: idempotencyKey,
  })
  .strict();

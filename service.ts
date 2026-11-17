import crypto from 'node:crypto';
import type { Principal } from '../../contracts.js';
import type { Database } from '../../database.js';
import { DomainError } from '../../errors.js';
import { command } from '../../command.js';
import { event } from '../../outbox.js';
import { audit, ready, requireHuman, sameVersion, uuid } from '../kz-common.js';
import { assertModuleEnabled } from '../kz-flags.js';
import { KZ_VALE_TROCA_EVENTS } from './events.js';
import { createStoreCreditSchema, useStoreCreditSchema } from './schema.js';

type StoreCreditRow = {
  id: string;
  customer_id: string;
  code: string;
  initial_cents: number;
  balance_cents: number;
  expires_at: string | null;
  status: string;
  version: number;
};

export class KzValeTrocaService {
  constructor(private readonly db: Database) {}

  async listByCustomer(p: Principal, customerId: string) {
    uuid.parse(customerId);
    requireHuman(p, 'GET', `/kz/vale-troca/cliente/${customerId}`);
    return this.db.workspace(p.workspaceId, async (tx) => {
      await assertModuleEnabled(tx, p.workspaceId, 'vale_troca');
      await ready(tx, 'crm.kz_store_credits', 'KZ_VALE_TROCA');
      const credits = (
        await tx.query<StoreCreditRow>(
          `SELECT * FROM crm.kz_store_credits
           WHERE workspace_id=$1 AND customer_id=$2 AND archived_at IS NULL
           ORDER BY created_at DESC`,
          [p.workspaceId, customerId],
        )
      ).rows;
      return { customer_id: customerId, credits };
    });
  }

  async create(p: Principal, raw: unknown) {
    requireHuman(p, 'POST', '/kz/vale-troca');
    const input = createStoreCreditSchema.parse(raw);
    return this.db.workspace(p.workspaceId, async (tx) => {
      await assertModuleEnabled(tx, p.workspaceId, 'vale_troca');
      await ready(tx, 'crm.kz_store_credits', 'KZ_VALE_TROCA');
      return command(tx, p, 'kz.vale_troca.criar', input.idempotency_key, input, async () => {
        const code = `VT-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
        const inserted = (
          await tx.query<StoreCreditRow>(
            `INSERT INTO crm.kz_store_credits
             (workspace_id, customer_id, return_case_id, code, initial_cents, balance_cents, expires_at, created_by)
             VALUES ($1, $2, $3, $4, $5, $5, $6, $7) RETURNING *`,
            [
              p.workspaceId,
              input.customer_id,
              input.return_case_id ?? null,
              code,
              input.initial_cents,
              input.expires_at ?? null,
              p.actorId,
            ],
          )
        ).rows[0];

        await event(
          tx,
          p,
          KZ_VALE_TROCA_EVENTS.CRIADO,
          inserted.id,
          `kz:vale:criar:${inserted.id}`,
          {
            customer_id: inserted.customer_id,
            code: inserted.code,
            initial_cents: Number(inserted.initial_cents),
          },
        );
        await audit(tx, p, KZ_VALE_TROCA_EVENTS.CRIADO, inserted.id, {
          code: inserted.code,
          initial_cents: Number(inserted.initial_cents),
        });
        return inserted;
      });
    });
  }

  async use(p: Principal, id: string, raw: unknown) {
    uuid.parse(id);
    requireHuman(p, 'POST', `/kz/vale-troca/${id}/usar`);
    const input = useStoreCreditSchema.parse(raw);
    return this.db.workspace(p.workspaceId, async (tx) => {
      await assertModuleEnabled(tx, p.workspaceId, 'vale_troca');
      await ready(tx, 'crm.kz_store_credits', 'KZ_VALE_TROCA');
      return command(
        tx,
        p,
        'kz.vale_troca.usar',
        input.idempotency_key,
        { id, ...input },
        async () => {
          const credit = (
            await tx.query<StoreCreditRow>(
              'SELECT * FROM crm.kz_store_credits WHERE workspace_id=$1 AND id=$2 AND archived_at IS NULL FOR UPDATE',
              [p.workspaceId, id],
            )
          ).rows[0];
          if (!credit) throw new DomainError('NOT_FOUND', 404);
          sameVersion(credit, input.expected_version);
          if (credit.status !== 'active') throw new DomainError('INVALID_STATE', 409);
          if (credit.expires_at && new Date(credit.expires_at).getTime() < Date.now()) {
            throw new DomainError('STORE_CREDIT_EXPIRED', 409);
          }

          const remaining = Number(credit.balance_cents) - input.amount_cents;
          if (remaining < 0) throw new DomainError('INSUFFICIENT_STORE_CREDIT', 409);
          const nextStatus = remaining === 0 ? 'exhausted' : 'active';

          const updated = (
            await tx.query<StoreCreditRow>(
              `UPDATE crm.kz_store_credits
               SET balance_cents=$2, status=$3, version=version+1, updated_at=now()
               WHERE workspace_id=$1 AND id=$4 RETURNING *`,
              [p.workspaceId, remaining, nextStatus, id],
            )
          ).rows[0];

          await event(
            tx,
            p,
            KZ_VALE_TROCA_EVENTS.USADO,
            id,
            `kz:vale:usar:${id}:${updated.version}`,
            {
              order_id: input.order_id,
              amount_cents: input.amount_cents,
              remaining_cents: remaining,
            },
          );
          await audit(tx, p, KZ_VALE_TROCA_EVENTS.USADO, id, {
            order_id: input.order_id,
            amount_cents: input.amount_cents,
          });
          return updated;
        },
      );
    });
  }
}

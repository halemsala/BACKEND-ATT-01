import '../helpers/explicit-demo-environment.js';
import crypto from 'node:crypto';
import test from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../../src/database.js';
import { KzCustosService } from '../../src/modules/kz-custos/service.js';
import {
  assertDomainError,
  blockExternalFetch,
  disableKzEnv,
  enableKzModule,
  principalA,
  principalB,
  snapshotPriceGuard,
} from './kz-test-helper.js';

test('kz-custos: custo medio com frete/taxas, idempotencia, RLS e guarda de preco', async () => {
  const restoreFetch = blockExternalFetch();
  const db = await Database.open();
  try {
    const pA = principalA('operator');
    const pB = principalB('operator');
    await db.bootstrapWorkspace(pA.workspaceId, 'Loja A');
    await db.bootstrapWorkspace(pB.workspaceId, 'Loja B');

    const svc = new KzCustosService(db);
    const variantId = crypto.randomUUID();

    disableKzEnv('KAZZUS_KZ_CUSTOS');
    await assertDomainError(() => svc.getByVariant(pA, variantId), 'MODULE_DISABLED', 404);

    await enableKzModule(db, pA.workspaceId, 'custos', 'KAZZUS_KZ_CUSTOS');
    await enableKzModule(db, pB.workspaceId, 'custos', 'KAZZUS_KZ_CUSTOS');

    const beforePrices = await snapshotPriceGuard(db, pA.workspaceId);

    await assertDomainError(
      () =>
        svc.recordEntry(principalA('viewer'), {
          variant_id: variantId,
          quantity: 2,
          unit_purchase_cents: 50000,
          idempotency_key: 'v-1',
        }),
      'FORBIDDEN',
      403,
    );
    await assertDomainError(
      () =>
        svc.recordEntry(principalA('sales'), {
          variant_id: variantId,
          quantity: 2,
          unit_purchase_cents: 50000,
          idempotency_key: 's-1',
        }),
      'FORBIDDEN',
      403,
    );

    const payload = {
      variant_id: variantId,
      quantity: 2,
      unit_purchase_cents: 50000,
      freight_cents: 2000,
      fees_cents: 0,
      idempotency_key: 'custo-1',
    };
    const e1 = await svc.recordEntry(pA, payload);
    const e2 = await svc.recordEntry(pA, payload);
    assert.equal(e1.id, e2.id);
    assert.equal(Number(e1.landed_unit_cents), 51000);

    await svc.recordEntry(pA, {
      variant_id: variantId,
      quantity: 2,
      unit_purchase_cents: 55000,
      freight_cents: 0,
      fees_cents: 0,
      idempotency_key: 'custo-2',
    });

    const summaryA = await svc.getByVariant(pA, variantId);
    assert.equal(summaryA.latest_moving_avg_cents, 53000);

    const summaryB = await svc.getByVariant(pB, variantId);
    assert.equal(summaryB.history.length, 0);

    assert.equal(await snapshotPriceGuard(db, pA.workspaceId), beforePrices);

    await db.workspace(pA.workspaceId, (tx) => tx.query('DROP TABLE crm.kz_landed_costs'));
    await assertDomainError(() => svc.getByVariant(pA, variantId), 'KZ_CUSTOS_MIGRATION_REQUIRED', 503);
  } finally {
    disableKzEnv('KAZZUS_KZ_CUSTOS');
    restoreFetch();
  }
});

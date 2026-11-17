import '../helpers/explicit-demo-environment.js';
import crypto from 'node:crypto';
import test from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../../src/database.js';
import { KzCrediarioService } from '../../src/modules/kz-crediario/service.js';
import {
  assertDomainError,
  blockExternalFetch,
  disableKzEnv,
  enableKzModule,
  principalA,
  principalB,
  snapshotPriceGuard,
} from './kz-test-helper.js';

test('kz-crediario: carne, baixa, idempotencia, conflito, RLS e flag', async () => {
  const restoreFetch = blockExternalFetch();
  const db = await Database.open();
  try {
    const pA = principalA('operator');
    const pB = principalB('operator');
    await db.bootstrapWorkspace(pA.workspaceId, 'Loja A');
    await db.bootstrapWorkspace(pB.workspaceId, 'Loja B');

    const svc = new KzCrediarioService(db);
    const customerId = crypto.randomUUID();

    disableKzEnv('KAZZUS_KZ_CREDIARIO');
    await assertDomainError(() => svc.getByCustomer(pA, customerId), 'MODULE_DISABLED', 404);

    await enableKzModule(db, pA.workspaceId, 'crediario', 'KAZZUS_KZ_CREDIARIO');
    await enableKzModule(db, pB.workspaceId, 'crediario', 'KAZZUS_KZ_CREDIARIO');

    const beforePrices = await snapshotPriceGuard(db, pA.workspaceId);

    await assertDomainError(
      () =>
        svc.create(principalA('viewer'), {
          customer_id: customerId,
          order_id: crypto.randomUUID(),
          principal_cents: 30000,
          installments_count: 3,
          first_due_date: '2026-12-10',
          idempotency_key: 'v-1',
        }),
      'FORBIDDEN',
      403,
    );
    await assertDomainError(
      () =>
        svc.create(principalA('sales'), {
          customer_id: customerId,
          order_id: crypto.randomUUID(),
          principal_cents: 30000,
          installments_count: 3,
          first_due_date: '2026-12-10',
          idempotency_key: 's-1',
        }),
      'FORBIDDEN',
      403,
    );

    const payload = {
      customer_id: customerId,
      order_id: crypto.randomUUID(),
      principal_cents: 30000,
      installments_count: 3,
      first_due_date: '2026-12-10',
      idempotency_key: 'cred-1',
    };
    const res1 = await svc.create(pA, payload);
    const res2 = await svc.create(pA, payload);
    assert.equal(res1.plan.id, res2.plan.id);
    assert.equal(res1.installments.length, 3);

    const firstInst = res1.installments[0] as { id: string; amount_cents: number };
    await assertDomainError(
      () =>
        svc.settleInstallment(pA, firstInst.id, {
          paid_cents: Number(firstInst.amount_cents),
          expected_version: 99,
          idempotency_key: 'bad-v',
        }),
      'VERSION_CONFLICT',
      409,
    );

    const settled = await svc.settleInstallment(pA, firstInst.id, {
      paid_cents: Number(firstInst.amount_cents),
      expected_version: 1,
      idempotency_key: 'pay-1',
    });
    assert.equal(settled.status, 'paid');

    const pastPlan = await svc.create(pA, {
      customer_id: customerId,
      order_id: crypto.randomUUID(),
      principal_cents: 10000,
      installments_count: 1,
      first_due_date: '2020-01-10',
      idempotency_key: 'cred-past',
    });
    assert.equal(pastPlan.installments.length, 1);
    const sweep1 = await svc.sweepDueInstallments(pA, { idempotency_key: 'sweep-1' });
    const sweep2 = await svc.sweepDueInstallments(pA, { idempotency_key: 'sweep-1' });
    assert.equal(sweep1.marked_overdue, 1);
    assert.equal(sweep2.marked_overdue, 1);

    const byCustomerB = await svc.getByCustomer(pB, customerId);
    assert.equal(byCustomerB.plans.length, 0);

    assert.equal(await snapshotPriceGuard(db, pA.workspaceId), beforePrices);

    await db.workspace(pA.workspaceId, (tx) =>
      tx.query('DROP TABLE crm.kz_credit_installments, crm.kz_credit_plans, crm.kz_credit_limits'),
    );
    await assertDomainError(
      () => svc.getByCustomer(pA, customerId),
      'KZ_CREDIARIO_MIGRATION_REQUIRED',
      503,
    );
  } finally {
    disableKzEnv('KAZZUS_KZ_CREDIARIO');
    restoreFetch();
  }
});

import '../helpers/explicit-demo-environment.js';
import test from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../../src/database.js';
import { KzCaixaService } from '../../src/modules/kz-caixa/service.js';
import {
  assertDomainError,
  blockExternalFetch,
  disableKzEnv,
  enableKzModule,
  principalA,
  principalB,
  snapshotPriceGuard,
} from './kz-test-helper.js';

test('kz-caixa: ciclo completo, idempotencia, conflito, RLS, flag e guarda de preco', async () => {
  const restoreFetch = blockExternalFetch();
  const db = await Database.open();
  try {
    const pA = principalA('operator');
    const pB = principalB('operator');
    await db.bootstrapWorkspace(pA.workspaceId, 'Loja A');
    await db.bootstrapWorkspace(pB.workspaceId, 'Loja B');

    const svc = new KzCaixaService(db);

    // Flag desligada por padrao -> MODULE_DISABLED
    disableKzEnv('KAZZUS_KZ_CAIXA');
    await assertDomainError(() => svc.getToday(pA), 'MODULE_DISABLED', 404);

    await enableKzModule(db, pA.workspaceId, 'caixa', 'KAZZUS_KZ_CAIXA');
    await enableKzModule(db, pB.workspaceId, 'caixa', 'KAZZUS_KZ_CAIXA');

    const beforePrices = await snapshotPriceGuard(db, pA.workspaceId);

    // viewer e sales bloqueados na escrita
    await assertDomainError(
      () => svc.open(principalA('viewer'), { opening_cents: 10000, idempotency_key: 'k-viewer' }),
      'FORBIDDEN',
      403,
    );
    await assertDomainError(
      () => svc.open(principalA('sales'), { opening_cents: 10000, idempotency_key: 'k-sales' }),
      'FORBIDDEN',
      403,
    );

    // Abertura + idempotencia
    const opened1 = await svc.open(pA, { opening_cents: 10000, idempotency_key: 'open-1' });
    const opened2 = await svc.open(pA, { opening_cents: 10000, idempotency_key: 'open-1' });
    assert.equal(opened1.id, opened2.id);

    // Isolamento RLS entre DEMO_A e DEMO_B
    const todayB = await svc.getToday(pB);
    assert.equal(todayB.session, null);

    // Conflito de versao
    await assertDomainError(
      () =>
        svc.move(pA, 'reforco', {
          session_id: opened1.id,
          amount_cents: 5000,
          reason: 'Troco',
          expected_version: 99,
          idempotency_key: 'ref-bad-ver',
        }),
      'VERSION_CONFLICT',
      409,
    );

    // Reforco + sangria + fechamento cego
    const ref = await svc.move(pA, 'reforco', {
      session_id: opened1.id,
      amount_cents: 5000,
      reason: 'Troco inicial',
      expected_version: 1,
      idempotency_key: 'ref-1',
    });
    assert.equal(Number(ref.session.expected_cents), 15000);

    const closed = await svc.close(pA, {
      session_id: opened1.id,
      counted_cents: 14500,
      expected_version: 2,
      idempotency_key: 'close-1',
    });
    assert.equal(closed.status, 'closed');
    assert.equal(Number(closed.difference_cents), -500);

    // Guarda de preco (diff = 0)
    const afterPrices = await snapshotPriceGuard(db, pA.workspaceId);
    assert.equal(afterPrices, beforePrices);

    // *_MIGRATION_REQUIRED quando tabela ausente
    await db.workspace(pA.workspaceId, (tx) => tx.query('DROP TABLE crm.kz_cash_movements, crm.kz_cash_sessions'));
    await assertDomainError(() => svc.getToday(pA), 'KZ_CAIXA_MIGRATION_REQUIRED', 503);
  } finally {
    disableKzEnv('KAZZUS_KZ_CAIXA');
    restoreFetch();
  }
});

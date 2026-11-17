import '../helpers/explicit-demo-environment.js';
import test from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../../src/database.js';
import { classifyAbc, KzAnaliseService } from '../../src/modules/kz-analise/service.js';
import {
  assertDomainError,
  blockExternalFetch,
  disableKzEnv,
  enableKzModule,
  principalA,
  principalB,
  snapshotPriceGuard,
} from './kz-test-helper.js';

test('kz-analise: curva ABC, parados, flag, RLS e guarda de preco', async () => {
  const restoreFetch = blockExternalFetch();
  const db = await Database.open();
  try {
    const pA = principalA('operator');
    const pB = principalB('operator');
    await db.bootstrapWorkspace(pA.workspaceId, 'Loja A');
    await db.bootstrapWorkspace(pB.workspaceId, 'Loja B');

    const svc = new KzAnaliseService(db);

    const abcPure = classifyAbc([
      { variant_id: 'v1', revenue_cents: 8000 },
      { variant_id: 'v2', revenue_cents: 1500 },
      { variant_id: 'v3', revenue_cents: 500 },
    ]);
    assert.equal(abcPure[0].curve, 'A');
    assert.equal(abcPure[1].curve, 'B');
    assert.equal(abcPure[2].curve, 'C');

    disableKzEnv('KAZZUS_KZ_ANALISE');
    await assertDomainError(() => svc.getAbc(pA, {}), 'MODULE_DISABLED', 404);

    await enableKzModule(db, pA.workspaceId, 'analise', 'KAZZUS_KZ_ANALISE');
    await enableKzModule(db, pB.workspaceId, 'analise', 'KAZZUS_KZ_ANALISE');

    const beforePrices = await snapshotPriceGuard(db, pA.workspaceId);

    const resA = await svc.getAbc(pA, { days: 30 });
    assert.equal(resA.days, 30);
    const viewerRead = await svc.getAbc(principalA('viewer'), { days: 30 });
    assert.equal(viewerRead.days, 30);
    await assertDomainError(() => svc.getAbc(principalA('agent'), {}), 'FORBIDDEN', 403);
    const staleB = await svc.getStaleStock(pB, { dias: 60 });
    assert.equal(staleB.dias, 60);

    assert.equal(await snapshotPriceGuard(db, pA.workspaceId), beforePrices);

    await db.workspace(pA.workspaceId, (tx) => tx.query('DROP TABLE crm.kz_report_snapshots'));
    await assertDomainError(() => svc.getAbc(pA, {}), 'KZ_ANALISE_MIGRATION_REQUIRED', 503);
  } finally {
    disableKzEnv('KAZZUS_KZ_ANALISE');
    restoreFetch();
  }
});

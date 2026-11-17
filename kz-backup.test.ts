import '../helpers/explicit-demo-environment.js';
import test from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../../src/database.js';
import { KzBackupService } from '../../src/modules/kz-backup/service.js';
import {
  assertDomainError,
  blockExternalFetch,
  disableKzEnv,
  enableKzModule,
  principalA,
  principalB,
  snapshotPriceGuard,
} from './kz-test-helper.js';

test('kz-backup: status, teste de restauracao, idempotencia, bloqueios, RLS e flag', async () => {
  const restoreFetch = blockExternalFetch();
  const db = await Database.open();
  try {
    const pA = principalA('operator');
    const pB = principalB('operator');
    await db.bootstrapWorkspace(pA.workspaceId, 'Loja A');
    await db.bootstrapWorkspace(pB.workspaceId, 'Loja B');

    const svc = new KzBackupService(db);

    disableKzEnv('KAZZUS_KZ_BACKUP');
    await assertDomainError(() => svc.status(pA), 'MODULE_DISABLED', 404);

    await enableKzModule(db, pA.workspaceId, 'backup', 'KAZZUS_KZ_BACKUP');
    await enableKzModule(db, pB.workspaceId, 'backup', 'KAZZUS_KZ_BACKUP');

    const beforePrices = await snapshotPriceGuard(db, pA.workspaceId);

    await assertDomainError(
      () =>
        svc.testRestore(principalA('viewer'), {
          backup_ref: '/tmp/sintetico.bak',
          idempotency_key: 'v-1',
        }),
      'FORBIDDEN',
      403,
    );
    await assertDomainError(
      () =>
        svc.testRestore(principalA('sales'), {
          backup_ref: '/tmp/sintetico.bak',
          idempotency_key: 's-1',
        }),
      'FORBIDDEN',
      403,
    );

    const payload = {
      backup_ref: '/tmp/sintetico-inexistente.bak',
      target_media: 'temp_restore' as const,
      idempotency_key: 'bkp-1',
    };
    const r1 = await svc.testRestore(pA, payload);
    const r2 = await svc.testRestore(pA, payload);
    assert.equal(r1.id, r2.id);

    await assertDomainError(
      () =>
        svc.testRestore(pA, {
          backup_ref: '../../etc/passwd',
          target_media: 'temp_restore',
          idempotency_key: 'bkp-traversal',
        }),
      'INVALID_PATH_REFERENCE',
      422,
    );

    const statusB = await svc.status(pB);
    assert.equal(statusB.checks.length, 0);

    assert.equal(await snapshotPriceGuard(db, pA.workspaceId), beforePrices);

    await db.workspace(pA.workspaceId, (tx) => tx.query('DROP TABLE crm.kz_backup_checks'));
    await assertDomainError(() => svc.status(pA), 'KZ_BACKUP_MIGRATION_REQUIRED', 503);
  } finally {
    disableKzEnv('KAZZUS_KZ_BACKUP');
    restoreFetch();
  }
});

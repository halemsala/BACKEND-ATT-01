#!/usr/bin/env node
/**
 * Pre-flight de integridade antes de aplicar o pacote Kazzus (somente leitura).
 * Uso no worktree C:\Kazzus:
 *   node fase-0/preflight-check.mjs --root /caminho/para/C-Kazzus
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const argIdx = process.argv.indexOf('--root');
const targetRoot = path.resolve(argIdx >= 0 && process.argv[argIdx + 1] ? process.argv[argIdx + 1] : process.cwd());

function sha256File(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

const report = {
  target_root: targetRoot,
  checked_at: new Date().toISOString(),
  migrations_free_094_to_118: true,
  conflicting_migrations: [],
  immutable_files_hashes: {
    package_json: sha256File(path.join(targetRoot, 'package.json')),
    package_lock_json: sha256File(path.join(targetRoot, 'package-lock.json')),
    authorization_ts: sha256File(path.join(targetRoot, 'src/authorization.ts')),
  },
  core_files_present: {
    contracts_ts: fs.existsSync(path.join(targetRoot, 'src/contracts.ts')),
    database_ts: fs.existsSync(path.join(targetRoot, 'src/database.ts')),
    errors_ts: fs.existsSync(path.join(targetRoot, 'src/errors.ts')),
    command_ts: fs.existsSync(path.join(targetRoot, 'src/command.ts')),
    outbox_ts: fs.existsSync(path.join(targetRoot, 'src/outbox.ts')),
    audit_events_ts: fs.existsSync(path.join(targetRoot, 'src/audit-events.ts')),
    model_runtime_ts: fs.existsSync(path.join(targetRoot, 'src/model-runtime.ts')),
    backup_ts: fs.existsSync(path.join(targetRoot, 'src/backup.ts')),
  },
};

const migDir = path.join(targetRoot, 'migrations');
if (fs.existsSync(migDir)) {
  const existing = fs.readdirSync(migDir);
  for (let n = 94; n <= 118; n++) {
    const prefix = `${String(n).padStart(3, '0')}_`;
    const hits = existing.filter((f) => f.startsWith(prefix));
    if (hits.length > 0) {
      report.migrations_free_094_to_118 = false;
      report.conflicting_migrations.push(...hits);
    }
  }
}

console.log(JSON.stringify(report, null, 2));
if (!report.migrations_free_094_to_118) {
  process.exitCode = 2;
}

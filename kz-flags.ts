import type { Database, SqlExecutor } from '../database.js';
import { DomainError } from '../errors.js';

export type KzModuleName =
  | 'flags'
  | 'caixa'
  | 'pagamento_misto'
  | 'taxas'
  | 'os'
  | 'usados'
  | 'orcamentos'
  | 'crediario'
  | 'financeiro'
  | 'vale_troca'
  | 'custos'
  | 'analise'
  | 'estoque'
  | 'seguranca'
  | 'backup'
  | 'regras'
  | 'previsao'
  | 'auditor'
  | 'deteccao'
  | 'recomendacao'
  | 'copiloto'
  | 'memoria'
  | 'orquestrador'
  | 'raciocinio';

export const ALL_KZ_MODULES: readonly KzModuleName[] = [
  'flags',
  'caixa',
  'pagamento_misto',
  'taxas',
  'os',
  'usados',
  'orcamentos',
  'crediario',
  'financeiro',
  'vale_troca',
  'custos',
  'analise',
  'estoque',
  'seguranca',
  'backup',
  'regras',
  'previsao',
  'auditor',
  'deteccao',
  'recomendacao',
  'copiloto',
  'memoria',
  'orquestrador',
  'raciocinio',
] as const;

export const ENV_KEY_MAP: Record<KzModuleName, string> = {
  flags: 'KAZZUS_KZ_FLAGS',
  caixa: 'KAZZUS_KZ_CAIXA',
  pagamento_misto: 'KAZZUS_KZ_PAGAMENTO_MISTO',
  taxas: 'KAZZUS_KZ_TAXAS',
  os: 'KAZZUS_KZ_OS',
  usados: 'KAZZUS_KZ_USADOS',
  orcamentos: 'KAZZUS_KZ_ORCAMENTOS',
  crediario: 'KAZZUS_KZ_CREDIARIO',
  financeiro: 'KAZZUS_KZ_FINANCEIRO',
  vale_troca: 'KAZZUS_KZ_VALE_TROCA',
  custos: 'KAZZUS_KZ_CUSTOS',
  analise: 'KAZZUS_KZ_ANALISE',
  estoque: 'KAZZUS_KZ_ESTOQUE',
  seguranca: 'KAZZUS_KZ_SEGURANCA',
  backup: 'KAZZUS_KZ_BACKUP',
  regras: 'KAZZUS_KZ_REGRAS',
  previsao: 'KAZZUS_KZ_PREVISAO',
  auditor: 'KAZZUS_KZ_AUDITOR',
  deteccao: 'KAZZUS_KZ_DETECCAO',
  recomendacao: 'KAZZUS_KZ_RECOMENDACAO',
  copiloto: 'KAZZUS_KZ_COPILOTO',
  memoria: 'KAZZUS_KZ_MEMORIA',
  orquestrador: 'KAZZUS_KZ_ORQUESTRADOR',
  raciocinio: 'KAZZUS_KZ_RACIOCINIO',
};

export const AUTOMATION_MODULES: ReadonlySet<KzModuleName> = new Set([
  'regras',
  'previsao',
  'auditor',
  'deteccao',
  'recomendacao',
  'copiloto',
  'memoria',
  'orquestrador',
  'raciocinio',
]);

export function isProcessFlagEnabled(module: KzModuleName): boolean {
  const envKey = ENV_KEY_MAP[module];
  return process.env[envKey] === 'YES';
}

export function isAutomationsKillSwitchOpen(): boolean {
  return process.env.KAZZUS_KZ_AUTOMATIONS === 'YES';
}

export function isManualAiOnly(): boolean {
  return process.env.KAZZUS_MANUAL_AI_ONLY === 'YES';
}

export async function isWorkspaceFlagEnabled(
  tx: SqlExecutor,
  workspaceId: string,
  module: KzModuleName,
): Promise<boolean> {
  const reg = await tx.query<{ reg: string | null }>(
    "SELECT to_regclass('crm.kz_feature_flags')::text AS reg",
  );
  if (!reg.rows[0]?.reg) {
    return false;
  }
  const row = await tx.query<{ enabled: boolean }>(
    'SELECT enabled FROM crm.kz_feature_flags WHERE workspace_id=$1 AND module=$2 AND archived_at IS NULL',
    [workspaceId, module],
  );
  return row.rows[0]?.enabled === true;
}

export async function assertModuleEnabled(
  tx: SqlExecutor,
  workspaceId: string,
  module: KzModuleName,
  options?: { isAutomation?: boolean },
): Promise<void> {
  if (!isProcessFlagEnabled(module)) {
    throw new DomainError('MODULE_DISABLED', 404);
  }
  if (options?.isAutomation && !isAutomationsKillSwitchOpen()) {
    throw new DomainError('MODULE_DISABLED', 404);
  }
  const workspaceEnabled = await isWorkspaceFlagEnabled(tx, workspaceId, module);
  if (!workspaceEnabled) {
    throw new DomainError('MODULE_DISABLED', 404);
  }
}

export async function assertJobEnabled(
  db: Database,
  workspaceId: string,
  module: KzModuleName,
): Promise<boolean> {
  if (!isProcessFlagEnabled(module) || !isAutomationsKillSwitchOpen()) {
    return false;
  }
  return db.workspace(workspaceId, (tx) => isWorkspaceFlagEnabled(tx, workspaceId, module));
}

export async function getAllFlagsStatus(tx: SqlExecutor, workspaceId: string) {
  const reg = await tx.query<{ reg: string | null }>(
    "SELECT to_regclass('crm.kz_feature_flags')::text AS reg",
  );
  const dbRows = reg.rows[0]?.reg
    ? (
        await tx.query<{ module: string; enabled: boolean; version: number; updated_at: string }>(
          'SELECT module, enabled, version, updated_at::text FROM crm.kz_feature_flags WHERE workspace_id=$1 AND archived_at IS NULL',
          [workspaceId],
        )
      ).rows
    : [];

  const dbMap = new Map(dbRows.map((r) => [r.module, r]));
  const automationsKillSwitchOpen = isAutomationsKillSwitchOpen();

  return ALL_KZ_MODULES.map((mod) => {
    const processEnabled = isProcessFlagEnabled(mod);
    const dbRow = dbMap.get(mod);
    const workspaceEnabled = dbRow?.enabled === true;
    const isAuto = AUTOMATION_MODULES.has(mod);
    const effectiveEnabled =
      processEnabled && workspaceEnabled && (!isAuto || automationsKillSwitchOpen);

    return {
      module: mod,
      env_key: ENV_KEY_MAP[mod],
      is_automation: isAuto,
      process_enabled: processEnabled,
      workspace_enabled: workspaceEnabled,
      effective_enabled: effectiveEnabled,
      version: dbRow?.version ?? 0,
      updated_at: dbRow?.updated_at ?? null,
    };
  });
}

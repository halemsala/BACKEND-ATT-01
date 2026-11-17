-- 107: modulo kz-backup (verificacao de restauracao e copia local para pen drive); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_backup_checks (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  backup_ref text NOT NULL CHECK (length(backup_ref) BETWEEN 1 AND 500),
  target_media text NOT NULL DEFAULT 'temp_restore' CHECK (target_media IN ('temp_restore', 'pendrive')),
  status text NOT NULL CHECK (status IN ('ok', 'failed')),
  sha256 text CHECK (sha256 IS NULL OR length(sha256) = 64),
  details_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

ALTER TABLE crm.kz_backup_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_backup_checks FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_backup_checks
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_backup_checks TO crm_app;

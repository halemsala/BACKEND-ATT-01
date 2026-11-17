-- 105: modulo kz-analise (snapshots opcionais de curva ABC e produtos parados); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_report_snapshots (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  report_kind text NOT NULL CHECK (report_kind IN ('abc', 'stale_stock')),
  params_json jsonb NOT NULL,
  payload_json jsonb NOT NULL,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

ALTER TABLE crm.kz_report_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_report_snapshots FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_report_snapshots
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_report_snapshots TO crm_app;

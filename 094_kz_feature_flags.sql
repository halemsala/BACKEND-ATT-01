-- 094: tabela de feature flags por loja para modulos kz; so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_feature_flags (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module text NOT NULL CHECK (length(module) BETWEEN 1 AND 64),
  enabled boolean NOT NULL DEFAULT false,
  updated_by text NOT NULL CHECK (length(updated_by) BETWEEN 1 AND 120),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, module)
);

CREATE INDEX IF NOT EXISTS idx_kz_feature_flags_lookup
  ON crm.kz_feature_flags (workspace_id, module)
  WHERE archived_at IS NULL;

ALTER TABLE crm.kz_feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_feature_flags FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_feature_flags
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_feature_flags TO crm_app;

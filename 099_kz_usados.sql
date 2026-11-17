-- 099: modulo kz-usados (referencia sugerida, avaliacao de troca e termo de compra); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_tradein_reference (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  model_name text NOT NULL CHECK (length(model_name) BETWEEN 1 AND 180),
  storage_gb integer NOT NULL CHECK (storage_gb > 0),
  grade text NOT NULL CHECK (grade IN ('A', 'B', 'C', 'D')),
  suggested_min_cents bigint NOT NULL CHECK (suggested_min_cents >= 0),
  suggested_max_cents bigint NOT NULL CHECK (suggested_max_cents >= suggested_min_cents),
  requires_anderson_auth boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, model_name, storage_gb, grade)
);

ALTER TABLE crm.kz_tradein_reference ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_tradein_reference FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_tradein_reference
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_tradein_reference TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_tradein_evaluations (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  seller_name text NOT NULL CHECK (length(seller_name) BETWEEN 1 AND 180),
  seller_rg_encrypted text NOT NULL,
  device_model text NOT NULL CHECK (length(device_model) BETWEEN 1 AND 180),
  storage_gb integer NOT NULL CHECK (storage_gb > 0),
  imei text NOT NULL CHECK (length(imei) BETWEEN 14 AND 20),
  imei_lookup_url text NOT NULL CHECK (length(imei_lookup_url) BETWEEN 1 AND 500),
  grade text NOT NULL CHECK (grade IN ('A', 'B', 'C', 'D')),
  checklist_json jsonb NOT NULL,
  suggested_min_cents bigint CHECK (suggested_min_cents IS NULL OR suggested_min_cents >= 0),
  suggested_max_cents bigint CHECK (suggested_max_cents IS NULL OR suggested_max_cents >= 0),
  status text NOT NULL DEFAULT 'evaluated' CHECK (status IN ('evaluated', 'approved', 'rejected')),
  inventory_unit_id uuid,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

ALTER TABLE crm.kz_tradein_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_tradein_evaluations FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_tradein_evaluations
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_tradein_evaluations TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_tradein_terms (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  evaluation_id uuid NOT NULL,
  term_text text NOT NULL CHECK (length(term_text) BETWEEN 1 AND 8000),
  receipt_mode text NOT NULL DEFAULT 'NAO_FISCAL' CHECK (receipt_mode = 'NAO_FISCAL'),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id, evaluation_id) REFERENCES crm.kz_tradein_evaluations(workspace_id, id)
);

ALTER TABLE crm.kz_tradein_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_tradein_terms FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_tradein_terms
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_tradein_terms TO crm_app;

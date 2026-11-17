-- 097: modulo kz-taxas (tabela de taxas por bandeira e parcelas); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_card_fee_tables (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  brand text NOT NULL CHECK (length(brand) BETWEEN 1 AND 40),
  installments integer NOT NULL CHECK (installments BETWEEN 1 AND 24),
  fee_percent numeric(5,2) NOT NULL CHECK (fee_percent >= 0 AND fee_percent <= 99.99),
  fixed_fee_cents bigint NOT NULL DEFAULT 0 CHECK (fixed_fee_cents >= 0),
  active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, brand, installments)
);

CREATE INDEX IF NOT EXISTS idx_kz_card_fee_tables_lookup
  ON crm.kz_card_fee_tables (workspace_id, brand, installments)
  WHERE archived_at IS NULL AND active = true;

ALTER TABLE crm.kz_card_fee_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_card_fee_tables FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_card_fee_tables
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_card_fee_tables TO crm_app;

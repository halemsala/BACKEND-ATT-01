-- 104: modulo kz-custos (custo de aquisicao com frete e taxas e custo medio); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_landed_costs (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  variant_id uuid NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_purchase_cents bigint NOT NULL CHECK (unit_purchase_cents >= 0),
  freight_cents bigint NOT NULL DEFAULT 0 CHECK (freight_cents >= 0),
  fees_cents bigint NOT NULL DEFAULT 0 CHECK (fees_cents >= 0),
  landed_unit_cents bigint NOT NULL CHECK (landed_unit_cents >= 0),
  moving_avg_cents bigint NOT NULL CHECK (moving_avg_cents >= 0),
  supplier_id uuid,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

CREATE INDEX IF NOT EXISTS idx_kz_landed_costs_variant
  ON crm.kz_landed_costs (workspace_id, variant_id, created_at DESC)
  WHERE archived_at IS NULL;

ALTER TABLE crm.kz_landed_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_landed_costs FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_landed_costs
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_landed_costs TO crm_app;

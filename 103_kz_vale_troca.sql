-- 103: modulo kz-vale-troca (vales de troca sem alteracao de preco); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_store_credits (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  return_case_id uuid,
  code text NOT NULL CHECK (length(code) BETWEEN 4 AND 40),
  initial_cents bigint NOT NULL CHECK (initial_cents > 0),
  balance_cents bigint NOT NULL CHECK (balance_cents >= 0),
  expires_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'exhausted', 'expired', 'cancelled')),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, code)
);

ALTER TABLE crm.kz_store_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_store_credits FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_store_credits
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_store_credits TO crm_app;

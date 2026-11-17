-- 101: modulo kz-crediario (limites, carnes e parcelas); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_credit_limits (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  limit_cents bigint NOT NULL CHECK (limit_cents >= 0),
  blocked boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, customer_id)
);

ALTER TABLE crm.kz_credit_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_credit_limits FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_credit_limits
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_credit_limits TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_credit_plans (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  order_id uuid NOT NULL,
  principal_cents bigint NOT NULL CHECK (principal_cents > 0),
  installments_count integer NOT NULL CHECK (installments_count BETWEEN 1 AND 36),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'settled', 'cancelled')),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

ALTER TABLE crm.kz_credit_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_credit_plans FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_credit_plans
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_credit_plans TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_credit_installments (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL,
  installment_number integer NOT NULL CHECK (installment_number >= 1),
  due_date date NOT NULL,
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  paid_cents bigint NOT NULL DEFAULT 0 CHECK (paid_cents >= 0),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'paid', 'overdue', 'cancelled')),
  paid_at timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id, plan_id) REFERENCES crm.kz_credit_plans(workspace_id, id)
);

ALTER TABLE crm.kz_credit_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_credit_installments FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_credit_installments
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_credit_installments TO crm_app;

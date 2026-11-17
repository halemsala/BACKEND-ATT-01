-- 102: modulo kz-financeiro (contas recorrentes e previsao de fluxo); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_recurring_bills (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  direction text NOT NULL CHECK (direction IN ('payable', 'receivable')),
  description text NOT NULL CHECK (length(description) BETWEEN 1 AND 300),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  due_date date NOT NULL,
  recurrence text NOT NULL DEFAULT 'once' CHECK (recurrence IN ('once', 'weekly', 'monthly')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'paid', 'cancelled')),
  finance_entry_id uuid,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

ALTER TABLE crm.kz_recurring_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_recurring_bills FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_recurring_bills
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_recurring_bills TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_cashflow_forecasts (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  inflow_cents bigint NOT NULL DEFAULT 0,
  outflow_cents bigint NOT NULL DEFAULT 0,
  projected_balance_cents bigint NOT NULL DEFAULT 0,
  alert_triggered boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, week_start)
);

ALTER TABLE crm.kz_cashflow_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_cashflow_forecasts FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_cashflow_forecasts
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_cashflow_forecasts TO crm_app;

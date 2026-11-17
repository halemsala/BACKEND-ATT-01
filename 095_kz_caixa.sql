-- 095: modulo kz-caixa (sessoes e movimentos de caixa); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_cash_sessions (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  opening_cents bigint NOT NULL CHECK (opening_cents >= 0),
  expected_cents bigint NOT NULL DEFAULT 0 CHECK (expected_cents >= 0),
  counted_cents bigint CHECK (counted_cents IS NULL OR counted_cents >= 0),
  difference_cents bigint,
  opened_by text NOT NULL CHECK (length(opened_by) BETWEEN 1 AND 120),
  closed_by text CHECK (closed_by IS NULL OR length(closed_by) BETWEEN 1 AND 120),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  notes text CHECK (notes IS NULL OR length(notes) <= 2000),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

CREATE INDEX IF NOT EXISTS idx_kz_cash_sessions_date
  ON crm.kz_cash_sessions (workspace_id, session_date, status)
  WHERE archived_at IS NULL;

ALTER TABLE crm.kz_cash_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_cash_sessions FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_cash_sessions
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_cash_sessions TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_cash_movements (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('sangria', 'reforco')),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  reason text NOT NULL CHECK (length(reason) BETWEEN 1 AND 500),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id, session_id) REFERENCES crm.kz_cash_sessions(workspace_id, id)
);

CREATE INDEX IF NOT EXISTS idx_kz_cash_movements_session
  ON crm.kz_cash_movements (workspace_id, session_id, created_at)
  WHERE archived_at IS NULL;

ALTER TABLE crm.kz_cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_cash_movements FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_cash_movements
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_cash_movements TO crm_app;

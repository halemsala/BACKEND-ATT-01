-- 117: blindagem Zero-Trust, SLA de OS, TTL de senha, taxa liquida em splits, cadeia HMAC e indices parciais; so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

ALTER TABLE crm.kz_service_orders
  ADD COLUMN IF NOT EXISTS passcode_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS sla_due_at timestamptz;

ALTER TABLE crm.kz_stepup_pins
  ADD COLUMN IF NOT EXISTS lockout_strikes integer NOT NULL DEFAULT 0 CHECK (lockout_strikes >= 0),
  ADD COLUMN IF NOT EXISTS quarantine_until timestamptz;

ALTER TABLE crm.kz_backup_checks
  ADD COLUMN IF NOT EXISTS hmac_signature text;

ALTER TABLE crm.kz_payment_splits
  ADD COLUMN IF NOT EXISTS fee_cents bigint NOT NULL DEFAULT 0 CHECK (fee_cents >= 0),
  ADD COLUMN IF NOT EXISTS net_amount_cents bigint;

CREATE TABLE IF NOT EXISTS crm.kz_security_hmac_log (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_category text NOT NULL CHECK (length(event_category) BETWEEN 1 AND 80),
  subject_id text NOT NULL CHECK (length(subject_id) BETWEEN 1 AND 120),
  payload_digest text NOT NULL CHECK (length(payload_digest) BETWEEN 32 AND 128),
  prev_hmac text NOT NULL CHECK (length(prev_hmac) BETWEEN 32 AND 128),
  entry_hmac text NOT NULL CHECK (length(entry_hmac) BETWEEN 32 AND 128),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

CREATE INDEX IF NOT EXISTS idx_kz_security_hmac_log_chain
  ON crm.kz_security_hmac_log (workspace_id, created_at DESC)
  WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_kz_service_orders_sla_open
  ON crm.kz_service_orders (workspace_id, status, sla_due_at)
  WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_kz_credit_installments_due_open
  ON crm.kz_credit_installments (workspace_id, status, due_date)
  WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_kz_recurring_bills_open_due
  ON crm.kz_recurring_bills (workspace_id, direction, due_date)
  WHERE archived_at IS NULL AND status = 'open';

CREATE INDEX IF NOT EXISTS idx_kz_payment_splits_order_active
  ON crm.kz_payment_splits (workspace_id, order_id, created_at)
  WHERE archived_at IS NULL;

ALTER TABLE crm.kz_security_hmac_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_security_hmac_log FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_security_hmac_log
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_security_hmac_log TO crm_app;

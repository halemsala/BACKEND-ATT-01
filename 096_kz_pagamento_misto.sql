-- 096: modulo kz-pagamento-misto (divisao de pagamento e troco); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_payment_splits (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL,
  split_group_id uuid NOT NULL,
  method text NOT NULL CHECK (method IN ('cash', 'pix_demo', 'debit', 'credit', 'store_credit', 'crediario')),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  received_cents bigint NOT NULL CHECK (received_cents >= 0),
  change_cents bigint NOT NULL DEFAULT 0 CHECK (change_cents >= 0),
  installments integer NOT NULL DEFAULT 1 CHECK (installments BETWEEN 1 AND 36),
  card_brand text CHECK (card_brand IS NULL OR length(card_brand) BETWEEN 1 AND 40),
  receipt_mode text NOT NULL DEFAULT 'NAO_FISCAL' CHECK (receipt_mode = 'NAO_FISCAL'),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

CREATE INDEX IF NOT EXISTS idx_kz_payment_splits_order
  ON crm.kz_payment_splits (workspace_id, order_id, created_at)
  WHERE archived_at IS NULL;

ALTER TABLE crm.kz_payment_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_payment_splits FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_payment_splits
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_payment_splits TO crm_app;

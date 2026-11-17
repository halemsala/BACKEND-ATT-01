-- 100: modulo kz-orcamentos (metadados de validade e conversao em venda); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_quote_meta (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quote_id uuid NOT NULL,
  valid_until timestamptz NOT NULL,
  pdf_template text NOT NULL DEFAULT 'nao_fiscal_padrao' CHECK (length(pdf_template) BETWEEN 1 AND 80),
  converted_order_id uuid,
  converted_at timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, quote_id)
);

ALTER TABLE crm.kz_quote_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_quote_meta FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_quote_meta
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_quote_meta TO crm_app;

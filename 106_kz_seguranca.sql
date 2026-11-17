-- 106: modulo kz-seguranca (PIN step-up com scrypt e grants temporarios); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_stepup_pins (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_id text NOT NULL CHECK (length(actor_id) BETWEEN 1 AND 120),
  pin_salt text NOT NULL CHECK (length(pin_salt) BETWEEN 16 AND 128),
  pin_hash text NOT NULL CHECK (length(pin_hash) BETWEEN 64 AND 256),
  failed_attempts integer NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  locked_until timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  UNIQUE (workspace_id, actor_id)
);

ALTER TABLE crm.kz_stepup_pins ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_stepup_pins FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_stepup_pins
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_stepup_pins TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_stepup_grants (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_id text NOT NULL CHECK (length(actor_id) BETWEEN 1 AND 120),
  scope text NOT NULL CHECK (scope IN ('discount', 'cancel', 'refund', 'sensitive', 'os_passcode')),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

ALTER TABLE crm.kz_stepup_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_stepup_grants FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_stepup_grants
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_stepup_grants TO crm_app;

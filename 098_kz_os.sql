-- 098: modulo kz-os (ordem de servico, checklist, pecas e fotos); so acrescimo; nada aqui envia mensagem, cobra, emite nota ou muda preco.

CREATE TABLE IF NOT EXISTS crm.kz_service_orders (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  device_model text NOT NULL CHECK (length(device_model) BETWEEN 1 AND 180),
  imei text CHECK (imei IS NULL OR length(imei) BETWEEN 8 AND 20),
  serial_number text CHECK (serial_number IS NULL OR length(serial_number) BETWEEN 1 AND 80),
  passcode_encrypted text,
  defect_summary text NOT NULL CHECK (length(defect_summary) BETWEEN 1 AND 500),
  status text NOT NULL DEFAULT 'intake' CHECK (status IN ('intake', 'diagnosing', 'awaiting_approval', 'repairing', 'ready', 'delivered', 'cancelled')),
  estimated_cents bigint CHECK (estimated_cents IS NULL OR estimated_cents >= 0),
  warranty_days integer NOT NULL DEFAULT 90 CHECK (warranty_days BETWEEN 0 AND 3650),
  warranty_id uuid,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id)
);

CREATE INDEX IF NOT EXISTS idx_kz_service_orders_status
  ON crm.kz_service_orders (workspace_id, status, created_at)
  WHERE archived_at IS NULL;

ALTER TABLE crm.kz_service_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_service_orders FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_service_orders
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_service_orders TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_service_order_checklists (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_order_id uuid NOT NULL,
  stage text NOT NULL CHECK (stage IN ('entry', 'exit')),
  items_json jsonb NOT NULL,
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id, service_order_id) REFERENCES crm.kz_service_orders(workspace_id, id)
);

ALTER TABLE crm.kz_service_order_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_service_order_checklists FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_service_order_checklists
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_service_order_checklists TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_service_order_parts (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_order_id uuid NOT NULL,
  variant_id uuid,
  part_name text NOT NULL CHECK (length(part_name) BETWEEN 1 AND 180),
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_cost_cents bigint NOT NULL CHECK (unit_cost_cents >= 0),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id, service_order_id) REFERENCES crm.kz_service_orders(workspace_id, id)
);

ALTER TABLE crm.kz_service_order_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_service_order_parts FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_service_order_parts
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_service_order_parts TO crm_app;

CREATE TABLE IF NOT EXISTS crm.kz_service_order_photos (
  workspace_id uuid NOT NULL REFERENCES crm.workspaces(id),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_order_id uuid NOT NULL,
  photo_ref text NOT NULL CHECK (length(photo_ref) BETWEEN 1 AND 500),
  caption text CHECK (caption IS NULL OR length(caption) <= 200),
  version integer NOT NULL DEFAULT 1,
  created_by text NOT NULL CHECK (length(created_by) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id, service_order_id) REFERENCES crm.kz_service_orders(workspace_id, id)
);

ALTER TABLE crm.kz_service_order_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.kz_service_order_photos FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_scope ON crm.kz_service_order_photos
  USING (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid)
  WITH CHECK (workspace_id = nullif(current_setting('app.workspace_id', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE ON crm.kz_service_order_photos TO crm_app;

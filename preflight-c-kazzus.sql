-- Pre-flight de compatibilidade SOMENTE LEITURA para C:\Kazzus (nao cria nem altera dados).
-- Execute antes de copiar migrations/094..118 no worktree isolado.

-- 1. Conferir schema e existencia das tabelas core esperadas pelos modulos kz-*
SELECT table_name,
       array_agg(column_name ORDER BY ordinal_position) AS columns
FROM information_schema.columns
WHERE table_schema = 'crm'
  AND table_name IN (
    'workspaces',
    'quotes',
    'quote_items',
    'inventory_units',
    'inventory_balances',
    'inventory_movements',
    'inventory_reservations',
    'finance_entries',
    'warranties',
    'tasks',
    'message_drafts',
    'agent_proposals',
    'opportunities',
    'outbox_events',
    'variant_costs',
    'orders',
    'order_items',
    'contacts'
  )
GROUP BY table_name
ORDER BY table_name;

-- 2. Conferir se a faixa de migracoes 094..118 esta totalmente livre (deve retornar 0 linhas se houver tabela schema_migrations/migrations)
SELECT 'CHECK_FILES_094_118_IN_REPO_AND_MIGRATION_TABLE' AS checklist_note;

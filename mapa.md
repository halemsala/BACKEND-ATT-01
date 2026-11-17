# Fase 0 — Inventário e Mapa de Compatibilidade (Kazzus CRM)

**Base de referência:** `Kazzus-prompt-backend-outra-IA_b8222f10.md` (contrato sobre `C:\Kazzus` commit `56f3aca`).
**Observação importante:** Os arquivos reais de `C:\Kazzus` e `Kazzus-funcoes-faltantes-completo.md` não estavam montados neste workspace; todos os pontos que dependem de inspeção direta na árvore `C:\Kazzus` estão marcados como `[CONFERIR NA BASE]`.

---

## 1) Mapa das 15 Funções P1 (Fase 1)

| # | Função | Decisão | O que reaproveita | Tabelas novas (`crm.`) | Endpoints (`kz/...`) | Eventos (`kz.*`) |
|---|---|---|---|---|---|---|
| 0 | `kz-flags` (controle de flags e saúde) | Criar | Padrão `safety-gates.ts` | `kz_feature_flags` (`094`) | `GET kz/flags`, `POST kz/flags/toggle`, `GET kz/saude` | `kz.flags.alterada` |
| 1 | `kz-caixa` (abertura, sangria, reforço, fechamento cego) | Estender com tabela nova | `finance_opening` / `finance_entries` (`finance.ts`) `[CONFERIR NA BASE]` | `kz_cash_sessions`, `kz_cash_movements` (`095`) | `GET kz/caixa/hoje`, `POST kz/caixa/abrir`, `POST kz/caixa/sangria`, `POST kz/caixa/reforco`, `POST kz/caixa/fechar` | `kz.caixa.aberto`, `kz.caixa.movimento`, `kz.caixa.fechado`, `kz.caixa.diferenca` |
| 2 | `kz-pagamento-misto` (várias formas e troco) | Criar ligado ao pedido/cotação | Pedidos/cotações existentes `[CONFERIR NA BASE]` | `kz_payment_splits` (`096`) | `POST kz/pagamentos/:pedido/dividir`, `GET kz/pagamentos/:pedido` | `kz.pagamento.dividido` |
| 3 | `kz-taxas` (parcelas, taxa da maquininha, lucro real) | Criar | Nenhuma (somente leitura/cálculo) | `kz_card_fee_tables` (`097`) | `GET kz/taxas`, `POST kz/taxas`, `POST kz/taxas/simular` | `kz.taxas.alteradas` |
| 4 | `kz-os` (OS, checklist, fotos, senha cifrada, peças, garantia) | Criar + reaproveitar garantia | `warranties.ts` (garantia do serviço) `[CONFERIR NA BASE]` | `kz_service_orders`, `kz_service_order_checklists`, `kz_service_order_parts`, `kz_service_order_photos` (`098`) | `POST kz/os`, `POST kz/os/:id/status`, `POST kz/os/:id/checklist`, `POST kz/os/:id/pecas`, `POST kz/os/:id/revelar-senha`, `GET kz/os` | `kz.os.criada`, `kz.os.status`, `kz.os.pronta`, `kz.os.senha_revelada` |
| 5 | `kz-usados` (avaliação, termo, checklist, IMEI, senha/RG cifrados) | Estender com tabela nova | `inspections` / `inventory_units` (`serial`, `used`) `[CONFERIR NA BASE]` | `kz_tradein_evaluations`, `kz_tradein_terms` (`099`) | `POST kz/usados/avaliacao`, `POST kz/usados/:id/aprovar`, `GET kz/usados/:id/termo` | `kz.usado.avaliado`, `kz.usado.aprovado` |
| 6 | `kz-usados` (tabela de referência só sugerida) | Criar | Nenhuma | `kz_tradein_reference` (`099`) | `GET kz/usados/referencia`, `POST kz/usados/referencia` | `kz.usado.referencia_alterada` |
| 7 | `kz-orcamentos` (orçamento -> venda) | Reaproveitar + estender meta | `quotes`, `quote_items` (`commerce.ts` / `crm.ts`) `[CONFERIR NA BASE]` | `kz_quote_meta` (`100`) | `POST kz/orcamentos/:id/converter` | `kz.orcamento.convertido` |
| 8 | `kz-crediario` (carnê, parcelas, limite por cliente) | Criar | `contacts` (referência de cliente) | `kz_credit_limits`, `kz_credit_plans`, `kz_credit_installments` (`101`) | `POST kz/crediario`, `POST kz/crediario/parcela/:id/baixa`, `POST kz/crediario/varredura`, `GET kz/crediario/cliente/:id` | `kz.crediario.criado`, `kz.parcela.vence_amanha`, `kz.parcela.atrasada`, `kz.parcela.paga` |
| 9 | `kz-financeiro` (contas a pagar/receber, fluxo 4 semanas) | Reaproveitar + estender | `finance_entries` (`finance.ts`) `[CONFERIR NA BASE]` | `kz_recurring_bills`, `kz_cashflow_forecasts` (`102`) | `GET kz/financeiro/fluxo`, `POST kz/financeiro/conta` | `kz.conta.vence`, `kz.fluxo.alerta` |
| 10 | `kz-vale-troca` (devolução, troca e vale-troca) | Reaproveitar + estender | `returns-refunds.ts`, `return_cases` `[CONFERIR NA BASE]` | `kz_store_credits` (`103`) | `POST kz/vale-troca`, `POST kz/vale-troca/:id/usar`, `GET kz/vale-troca/cliente/:id` | `kz.vale.criado`, `kz.vale.usado` |
| 11 | `kz-custos` (custo médio e custo de aquisição) | Reaproveitar + estender | `variant_costs` `[CONFERIR NA BASE]` | `kz_landed_costs` (`104`) | `POST kz/custos/entrada`, `GET kz/custos/:variante` | `kz.custo.atualizado` |
| 12 | `kz-analise` (curva ABC e produto parado, só leitura) | Criar leitura agregada | `inventory_balances`, `inventory_movements`, vendas `[CONFERIR NA BASE]` | `kz_report_snapshots` (`105`) | `GET kz/analise/abc`, `GET kz/analise/parados` | nenhum |
| 13 | `kz-estoque` (estoque disponível vs reservado) | Reaproveitar (só leitura) | `inventory_balances`, `inventory_reservations` | nenhuma | `GET kz/estoque/disponivel` | nenhum |
| 14 | `kz-seguranca` (PIN step-up + lockout + log) | Criar camada acima de `authorization.ts` | `writeAuditEvent` / `security-log.ts` | `kz_stepup_pins`, `kz_stepup_grants` (`106`) | `GET kz/seguranca/status`, `POST kz/seguranca/pin`, `POST kz/seguranca/confirmar` | `kz.seguranca.confirmado` |
| 15 | `kz-backup` (teste de restauração + status pen drive + HMAC) | Reaproveitar + registrar | `backup.ts` (`verifyBackup`, `restoreBackup`) `[CONFERIR NA BASE]` | `kz_backup_checks` (`107`, `117`) | `POST kz/backup/testar`, `GET kz/backup/status`, `POST kz/manutencao/retencao` | `kz.backup.ok`, `kz.backup.falhou` |

---

## 2) Mapa das 15 Automações P1 + Orquestração (Fase 2)

| # | Automação | Módulo | Decisão | Tabelas novas (`crm.`) | Endpoints (`kz/...`) | Gatilho / Job |
|---|---|---|---|---|---|---|
| 1 | Motor de regras se -> então + DAG anti-loop + janela horária + simulação 7d + desfazer | `kz-regras` | Criar (consome `crm.outbox_events`) | `kz_rules`, `kz_rule_runs`, `kz_rule_cursors` (`108`, `118`) | `GET/POST kz/regras`, `GET kz/regras/execucoes`, `POST kz/regras/instalar-presets`, `POST kz/regras/:id/ligar`, `POST kz/regras/:id/simular`, `POST kz/regras/:id/simular-historico`, `POST kz/regras/desligar-tudo`, `POST kz/regras/execucao/:id/desfazer` | Polling/job do `outbox_events` com cursor, 9 ações, DAG e circuit breaker |
| 2 | Fila de aprovação unificada | `kz-aprovacoes` (em `kz-regras`) | Reaproveitar `AiProposals` + `message_drafts` | nenhuma | `GET kz/aprovacoes` | Leitura agregada |
| 3 | Pedido pago -> tarefa de separação | `kz-regras` (preset pronto) | Reaproveitar motor `kz-regras` | nenhuma | via `kz/regras/instalar-presets` | Evento `payment.*` / pedido pago |
| 4 | Venda de celular -> garantia + pós-venda | `kz-regras` (preset pronto) | Reaproveitar `warranties` + `crm.tasks` + `message_drafts` | nenhuma | via `kz/regras/instalar-presets` | Venda com unidade `serial` |
| 5 | Previsão de ruptura + curva ABC (A/B/C) + capital parado | `kz-previsao` | Reaproveitar `stock-replenishment.ts` + 7d/30d/90d + `kz_landed_costs` | `kz_stock_forecasts` (`109`, `118`) | `GET kz/previsao/ruptura` | Job diário -> proposta em `AiProposals` |
| 6 | Calendário sazonal da Paraíba + dias de pagamento | `kz-previsao` | Criar (datas editáveis pelo Anderson) | `kz_calendar_events` (`109`) | `GET/POST kz/calendario` | Usado no cálculo da previsão |
| 7 | Agente Auditor diário | `kz-auditor` | Reaproveitar `verifyAuditChain` + `health_score` | `kz_audit_reports` (`110`) | `GET kz/auditor/hoje` | Job 07:00 |
| 8 | IMEI duplicado ou inválido (cruzado `kz-os` x `kz-usados`) | `kz-deteccao` | Reaproveitar `inventory_units` | nenhuma | `GET kz/deteccao/imei`, `GET kz/os/sla/alertas` | Validação + consulta Luhn/duplicidade |
| 9 | Comprovante de Pix repetido/suspeito + split smurfing | `kz-deteccao` | Criar registro de hash + rajada 15 min | `kz_pix_receipts` (`111`) | `POST kz/pix/comprovante` | Hash SHA-256 + alerta se repetir |
| 10 | Anomalia no fechamento de caixa | `kz-deteccao` | Híbrido Z-score + IQR sobre `kz.caixa.fechado` | nenhuma | via alerta/evento | Job / handler de evento |
| 11 | Margem negativa / preço divergente (só alerta) | `kz-deteccao` | Leitura de vendas vs `variant_costs` | nenhuma | `GET kz/deteccao/margem` | Alerta somente leitura (R1) |
| 12 | Acessório certo + comprados juntos | `kz-recomendacao` | Support/Confidence coocorrência | `kz_basket_pairs` (`112`) | `GET kz/recomendacao/carrinho` | Job semanal |
| 13 | Lista do dia + cooldown 7d + pós-venda 7d em rascunho | `kz-recomendacao` | Reaproveitar `message_drafts` + filtro LGPD | `kz_daily_contacts` (`112`) | `GET kz/recomendacao/contatos-hoje` | Job 08:00 -> gera rascunhos |
| 14 | Briefing da manhã + "Explique este número" + roteamento dual | `kz-copiloto` | 10 métricas + contexto loja + `ModelRuntime` (127.0.0.1) | `kz_briefings` (`113`) | `GET kz/copiloto/briefing`, `POST kz/copiloto/explicar` | Job 08:00 + resposta com SQL usada |
| 15 | Memória do cliente/loja com TTL automático LGPD + feedback | `kz-memoria` | Criar | `kz_customer_memory`, `kz_store_rules`, `kz_suggestion_feedback` (`114`, `118`) | `GET/POST kz/memoria/cliente/:id`, `POST kz/sugestoes/:id/feedback`, `POST kz/memoria/apagar` | Sob demanda + varredura TTL |
| 16 | Orquestrador Mestre + Lock Consultivo + Backoff DLQ + Retenção | `kz-orquestrador` | Encadeia todos os motores com advisory lock Postgres e backoff DLQ | `kz_operational_alerts`, `kz_pipeline_runs`, `kz_outbox_dlq`, `kz_retention_runs` (`115`, `118`) | `GET kz/orquestrador/painel`, `GET kz/orquestrador/alertas`, `POST kz/orquestrador/alertas/:id/resolver`, `POST kz/orquestrador/ciclo`, `POST kz/orquestrador/dlq/:id/reprocessar` | Job contínuo a cada 5 min |
| 17 | Motor de Raciocínio Dual (`fast`/`reasoning`), Cache + Blackboard | `kz-raciocinio` | Empacota contexto compacto + roteamento dual LLM local + 9 ferramentas fechadas | `kz_reasoning_cache`, `kz_reasoning_runs`, `kz_agent_blackboard`, `kz_security_hmac_log` (`116`, `117`, `118`) | `GET kz/raciocinio/painel`, `GET kz/raciocinio/ferramentas`, `GET kz/raciocinio/agentes/quadro`, `POST kz/raciocinio/analisar`, `POST kz/raciocinio/agentes/sincronizar`, `POST kz/raciocinio/ferramentas/executar` | Sincronizado no ciclo do Orquestrador + sob demanda |

---

## 3) Dúvidas, Pre-Flight e Conferências Pendentes na Base Real (`[CONFERIR NA BASE]`)

1. Rodar `fase-0/preflight-c-kazzus.sql` no Postgres e `node fase-0/preflight-check.mjs` antes de aplicar `094..118`.
2. Confirmar as assinaturas exatas de importação de `Database`, `Principal`, `DomainError`, `command`, `event`, `writeAuditEvent`, `ModelRuntime`, `verifyBackup`, `restoreBackup` e `registerJob`.
3. Confirmar os nomes exatos das colunas de `crm.quotes`, `crm.finance_entries`, `crm.inventory_units`, `crm.inventory_balances`, `crm.inventory_reservations`, `crm.variant_costs`, `crm.agent_proposals`, `crm.message_drafts` e `crm.tasks` para ajustar eventuais joins SQL.
4. Confirmar com o Anderson as datas do calendário da Paraíba (aniversário de Cajazeiras e feriados/feiras locais).
5. Confirmar se vendedores (`sales`) continuarão bloqueados nas rotas `kz/*` até eventual liberação em `src/authorization.ts`.

# Módulo `kz-vale-troca`

Emissão e utilização de vale-troca ligado a casos de devolução existentes (`return_cases`).

- **Tabela (`103_kz_vale_troca.sql`):** `crm.kz_store_credits`.
- **Rotas:** `GET kz/vale-troca/cliente/:id`, `POST kz/vale-troca`, `POST kz/vale-troca/:id/usar`.
- **Eventos:** `kz.vale.criado`, `kz.vale.usado`.
- **Flags:** `KAZZUS_KZ_VALE_TROCA=YES` + `crm.kz_feature_flags(module='vale_troca', enabled=true)`.
- **Exige autorização do Anderson:** não cria cupom de desconto nem altera preço (R1).

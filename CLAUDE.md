# Nexus Platform — Índice para IA

Plataforma de gestão de pedidos B2B. Microsserviços com 3 bounded contexts: **Orders**, **Catalog** e **Logistics**.

> Para visão geral, stack e início rápido: leia o `README.md`.

---

## Onde encontrar cada tipo de conhecimento

| Tipo | Onde |
|------|------|
| Stack, estrutura e início rápido | `README.md` |
| Convenções de código do projeto | `README.md` → seção Convenções |
| Decisões arquiteturais (ADRs) | `docs/adr/` |
| Setup e teardown do ambiente local | `docs/runbook/local-env.md` |
| Problemas com Kafka | `docs/runbook/kafka.md` |
| Problemas com k3s e ArgoCD | `docs/runbook/k3s-argocd.md` |
| Segurança do repositório e CI/CD | `docs/security.md` |
| Self-hosted runner | `RUNNER.md` |
| Regras de negócio — Orders | `orders-service/docs/business-rules.md` |
| API REST — Orders | `orders-service/docs/api.md` |
| Regras de negócio — Catalog | `catalog-service/docs/business-rules.md` |
| PricingEngine | `catalog-service/docs/pricing-engine.md` |
| RPI (Reserva Preventiva de Itens) | `logistics-service/docs/rpi.md` |
| Transportadoras | `logistics-service/docs/carriers.md` |
| Contexto por serviço (para IA) | `<servico>/CLAUDE.md` |

---

## Comunicação entre serviços

- **Síncrona:** apenas dentro do mesmo bounded context ou via API Gateway
- **Assíncrona:** Kafka para comunicação entre bounded contexts (ADR-001)

| Tópico | Publicado por | Consumido por |
|--------|--------------|--------------|
| `orders.confirmed` | orders-service | logistics-service (RPI) |
| `orders.dispatched` | orders-service | — |
| `orders.cancelled` | orders-service | logistics-service (libera RPI) |
| `logistics.tracking` | logistics-service | frontend (SSE) |
| `catalog.updated` | catalog-service | catalog-service (invalida cache) |

---

## Autenticação

Keycloak com OAuth 2.0 + JWT. Roles: `ROLE_BUYER`, `ROLE_SALES`, `ROLE_LOGISTICS`, `ROLE_ADMIN`. Validação via `@PreAuthorize` em cada microsserviço. O API Gateway valida a assinatura JWT e propaga o token para os serviços downstream.

---

## ADRs vigentes

- [ADR-001](docs/adr/ADR-001-kafka-async-communication.md) — Kafka para comunicação assíncrona
- [ADR-002](docs/adr/ADR-002-redis-catalog-cache.md) — Cache Redis no catálogo
- [ADR-003](docs/adr/ADR-003-stock-reservation-on-confirm.md) — Reserva de estoque na confirmação

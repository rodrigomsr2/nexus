# Nexus Platform — Contexto para IA

Plataforma de gestão de pedidos B2B da TechCorp Ltda. Arquitetura de microsserviços com 3 bounded contexts: **Orders**, **Catalog** e **Logistics**.

## Stack

| Camada | Tecnologia |
|--------|------------|
| Backend | Java 21 + Spring Boot 3.2 |
| Frontend | React 18 + TypeScript + Vite |
| Banco | PostgreSQL 16 (schemas separados por bounded context) |
| Cache | Redis 7.2 (TTL 15min, invalidação por evento) |
| Mensageria | Apache Kafka 3.6 |
| Auth | Keycloak 23 — OAuth 2.0 + JWT |
| Container | Docker + Kubernetes + Helm |
| CI/CD | GitHub Actions + ArgoCD (GitOps) |

## Estrutura do repositório

```
nexus/
├── orders-service/       # Bounded context: Pedidos
├── catalog-service/      # Bounded context: Catálogo + PricingEngine
├── logistics-service/    # Bounded context: Logística + Transportadoras
├── api-gateway/          # Spring Cloud Gateway
├── frontend/             # React + Vite + TypeScript
├── infra/
│   ├── docker/           # init.sql, keycloak-realm.json
│   ├── k8s/              # Deployments, HPA, PDB por serviço
│   └── helm/             # Helm charts
└── .github/workflows/    # CI/CD pipeline
```

## Convenções do projeto

- Pacote base: `com.techcorp.nexus.<servico>`
- Nomenclatura de SKU: `NX-PRD-XXXXX`
- Nomenclatura de pedido: `NX-XXXXX`
- Usar `jakarta.*` (não `javax.*`) — projeto está em Spring Boot 3.x / Jakarta EE 10
- Records Java para eventos e DTOs imutáveis
- Switch expressions (Java 14+) para máquinas de estado
- Flyway para migrations — nunca alterar migrations já aplicadas
- Nunca commitar secrets — usar Kubernetes Secrets ou vault em produção

## Comunicação entre serviços

- **Síncrona:** apenas dentro do mesmo bounded context ou via API Gateway
- **Assíncrona:** Kafka para comunicação entre bounded contexts (ADR-001)
- Tópicos: `orders.confirmed`, `orders.dispatched`, `orders.cancelled`, `logistics.tracking`

## Autenticação

Keycloak com OAuth 2.0 + JWT. Roles: `ROLE_BUYER`, `ROLE_SALES`, `ROLE_LOGISTICS`, `ROLE_ADMIN`. Validação via `@PreAuthorize` em cada microsserviço.

## Build

```bash
# Compilar todos os serviços
./gradlew build

# Rodar testes
./gradlew test

# Gerar JAR de um serviço específico
./gradlew :orders-service:bootJar
```

## Ambiente local

```bash
# Subir toda a infra
docker compose up -d postgres redis zookeeper kafka keycloak

# Aguardar healthchecks e então subir os serviços
docker compose up -d orders-service catalog-service logistics-service api-gateway frontend
```

Serviços: Frontend :3000 · Gateway :8080 · Orders :8081 · Catalog :8082 · Logistics :8083 · Keycloak :8180 · Kafka UI :8090

## Times

| Time | Canal | Responsável |
|------|-------|-------------|
| Backend Core | `#nexus-backend` | — |
| Logística | `#nexus-logistics` | — |
| Frontend | `#nexus-frontend` | — |
| Infra | `#nexus-infra` | — |

**Tech Lead:** Ana Souza · **Arquiteto:** Rafael Lima · **PM:** Carlos Mendes

## ADRs vigentes

- **ADR-001** — Kafka para comunicação assíncrona entre bounded contexts
- **ADR-002** — Cache Redis no catálogo (reduz 90% leituras no banco)
- **ADR-003** — Reserva de estoque na confirmação do pedido, não no rascunho

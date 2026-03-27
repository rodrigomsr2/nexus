# Projeto Nexus

Plataforma de gestão de pedidos B2B. Arquitetura de microsserviços com 3 bounded contexts: **Orders**, **Catalog** e **Logistics**.

## Stack

| Camada | Tecnologia |
|--------|------------|
| Backend | Java 21 + Spring Boot 3.2 |
| Frontend | React 18 + TypeScript + Vite |
| Banco | PostgreSQL 16 |
| Cache | Redis 7.2 |
| Mensageria | Apache Kafka 3.6 |
| Auth | Keycloak 23 (OAuth 2.0 + JWT) |
| Container | Docker + Kubernetes (Helm) |
| CI/CD | GitHub Actions + ArgoCD |

## Estrutura do repositório

```
nexus/
├── orders-service/        # Bounded context: Pedidos
├── catalog-service/       # Bounded context: Catálogo + PricingEngine
├── logistics-service/     # Bounded context: Logística + Transportadoras
├── api-gateway/           # Spring Cloud Gateway (JWT, rate limiting, routing)
├── frontend/              # React app (Vite + TypeScript)
├── infra/
│   ├── docker/            # init.sql, keycloak-realm.json
│   ├── k8s/               # Deployments, HPA, PDB por serviço
│   └── helm/              # Helm charts
├── docs/                  # ADRs, runbooks, notas técnicas
├── .github/workflows/     # CI/CD pipeline
└── docker-compose.yml     # Ambiente local completo
```

## Início rápido

### Pré-requisitos

- Docker 24+ e Docker Compose v2
- Java 21 (para rodar serviços localmente sem Docker)
- Node.js 20+ (para o frontend)

### 1. Subir a infraestrutura via script

```bash
chmod +x setup-local-env.sh
./setup-local-env.sh
```

O script instala dependências (k3s, Helm, yq), sobe a infra via Docker Compose, configura o k3s e instala o ArgoCD. Veja `docs/runbook/local-env.md` para detalhes completos.

### Serviços disponíveis após o setup

| Serviço | URL |
|---------|-----|
| Frontend | http://localhost:3000 |
| API Gateway | http://localhost:8080 |
| Orders Service | http://localhost:8081 |
| Catalog Service | http://localhost:8082 |
| Logistics Service | http://localhost:8083 |
| Keycloak Admin | http://localhost:8180 (admin/admin) |
| Kafka UI | http://localhost:8090 |
| ArgoCD UI | https://HOST_IP:30443 |
| PostgreSQL | localhost:5432 |

### 2. Obter token JWT

```bash
curl -X POST http://localhost:8180/realms/nexus/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=nexus-backend" \
  -d "username=admin@nexus.local" \
  -d "password=admin123"
```

### 3. Criar um pedido (exemplo)

```bash
TOKEN="<seu_jwt_aqui>"

# Criar rascunho
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "client-001",
    "clientType": "PJ",
    "items": [
      { "sku": "NX-PRD-00001", "quantity": 2 },
      { "sku": "NX-PRD-00003", "quantity": 5 }
    ]
  }'

# Confirmar pedido (substitua pelo ID retornado)
curl -X PUT http://localhost:8080/api/v1/orders/{id}/submit \
  -H "Authorization: Bearer $TOKEN"
```

### 4. Rodar apenas o frontend localmente

```bash
cd frontend
npm install
echo "VITE_API_BASE_URL=http://localhost:8080" > .env.local
npm run dev
```

### 5. Rodar um serviço Java localmente (sem Docker)

```bash
# Subir apenas a infra
docker compose up -d postgres redis zookeeper kafka keycloak

# Rodar o serviço desejado
cd orders-service
../gradlew :orders-service:bootRun
```

## Testes

```bash
# Unitários
./gradlew test

# Integração (requer Docker para Testcontainers)
./gradlew test -Pintegration-tests

# Frontend
cd frontend && npm test
```

## Build

```bash
# Compilar todos os serviços
./gradlew build

# Gerar JAR de um serviço específico
./gradlew :orders-service:bootJar
```

## Documentação

| Documento | Descrição |
|-----------|-----------|
| `docs/adr/` | Decisões arquiteturais (ADRs) |
| `docs/runbook/local-env.md` | Setup, teardown e deploy do ambiente local |
| `docs/runbook/kafka.md` | Problemas e soluções do Kafka |
| `docs/runbook/k3s-argocd.md` | Problemas e soluções do k3s/ArgoCD |
| `docs/security.md` | Segurança do repositório e CI/CD |
| `RUNNER.md` | Self-hosted runner do GitHub Actions (CI/CD) |
| `orders-service/docs/` | Regras de negócio e API do bounded context Orders |
| `catalog-service/docs/` | Regras de negócio e PricingEngine |
| `logistics-service/docs/` | RPI, transportadoras e rastreamento |

## Convenções

- Pacote base: `com.rodrigomsr2.nexus.<servico>`
- Nomenclatura de SKU: `NX-PRD-XXXXX`
- Nomenclatura de pedido: `NX-XXXXX`
- Usar `jakarta.*` (não `javax.*`) — Spring Boot 3.x / Jakarta EE 10
- Records Java para eventos e DTOs imutáveis
- Switch expressions (Java 14+) para máquinas de estado
- Flyway para migrations — nunca alterar migrations já aplicadas
- Nunca commitar secrets — usar Kubernetes Secrets ou vault em produção

## ADRs vigentes

- [ADR-001](docs/adr/ADR-001-kafka-async-communication.md) — Kafka para comunicação assíncrona entre bounded contexts
- [ADR-002](docs/adr/ADR-002-redis-catalog-cache.md) — Cache Redis no catálogo (reduz 90% das leituras no banco)
- [ADR-003](docs/adr/ADR-003-stock-reservation-on-confirm.md) — Reserva de estoque na confirmação do pedido, não no rascunho

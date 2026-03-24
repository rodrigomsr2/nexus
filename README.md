# Projeto Nexus

Plataforma de gestão de pedidos B2B

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

## Estrutura

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
├── .github/workflows/     # CI/CD pipeline
└── docker-compose.yml     # Ambiente local completo
```

## Início rápido (ambiente local)

### Pré-requisitos

- Docker 24+ e Docker Compose v2
- Java 21 (para rodar serviços localmente sem Docker)
- Node.js 20+ (para o frontend)

### 1. Subir toda a infraestrutura

```bash
docker compose up -d
```

Aguarde os health checks. Serviços disponíveis:

| Serviço | URL |
|---------|-----|
| Frontend | http://localhost:3000 |
| API Gateway | http://localhost:8080 |
| Orders Service | http://localhost:8081 |
| Catalog Service | http://localhost:8082 |
| Logistics Service | http://localhost:8083 |
| Keycloak Admin | http://localhost:8180 (admin/admin) |
| Kafka UI | http://localhost:8090 |
| PostgreSQL | localhost:5432 |

### 2. Obter token JWT

```bash
curl -X POST http://localhost:8180/realms/nexus/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=nexus-backend" \
  -d "username=admin@techcorp.com" \
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

### 5. Rodar os serviços Java localmente

```bash
# Subir apenas a infra (postgres, redis, kafka, keycloak)
docker compose up -d postgres redis kafka zookeeper keycloak

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

## Variáveis de ambiente

Veja o arquivo `.env.example` ou as seções `environment:` no `docker-compose.yml`.
Nunca commitar senhas reais — use Kubernetes Secrets ou um vault em produção.

## Bounded Contexts

### Orders

**Ciclo de vida do pedido:**
```
RASCUNHO → CONFIRMADO → EM_SEPARACAO → DESPACHADO → ENTREGUE
                ↓
           CANCELADO
```

| Status | Descrição |
|--------|-----------|
| `RASCUNHO` | Pedido criado mas não submetido. Itens podem ser alterados. |
| `CONFIRMADO` | Submetido e aprovado pelo sistema de crédito. Bloqueado para edição. |
| `EM_SEPARACAO` | Depósito iniciou a separação dos itens. |
| `DESPACHADO` | Saiu do depósito com código de rastreamento. |
| `ENTREGUE` | Confirmação de entrega recebida. |
| `CANCELADO` | Solicitado antes do despacho. Após despacho, abre-se uma devolução. |

**Regras de negócio:**

1. **Pedido mínimo** — R$ 500,00 para clientes PJ; R$ 100,00 para PF.
2. **Prazo de cancelamento** — até 2 horas após a confirmação sem custo. Após isso, taxa de 5% sobre o valor do pedido.
3. **Limite de crédito** — o sistema consulta o `CreditService` antes de confirmar. Se o cliente estiver inadimplente ou acima do limite, o pedido vai para revisão manual.
4. **Desconto por volume** — pedidos acima de R$ 5.000,00 recebem 3% de desconto automático.
5. **Itens descontinuados** — não podem ser adicionados a novos pedidos, mas pedidos existentes com esses itens não são afetados.

**API:**

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `POST` | `/api/v1/orders` | Cria rascunho |
| `GET` | `/api/v1/orders/{id}` | Detalha pedido |
| `PUT` | `/api/v1/orders/{id}/submit` | Confirma pedido |
| `DELETE` | `/api/v1/orders/{id}` | Cancela pedido |
| `GET` | `/api/v1/orders?clientId=X` | Lista pedidos do cliente |

**Eventos Kafka:**

| Tópico | Evento |
|--------|--------|
| `orders.confirmed` | `OrderConfirmedEvent` |
| `orders.dispatched` | `OrderDispatchedEvent` |
| `orders.cancelled` | `OrderCancelledEvent` |

---

### Catalog

**Estrutura de produto:** cada produto possui SKU (ex: `NX-PRD-00123`), categoria em hierarquia de até 3 níveis, preço base, preço contratual por cliente ou grupo, e status (`ATIVO`, `DESCONTINUADO`, `SUSPENSO`).

**PricingEngine** — resolve o preço final na seguinte ordem de prioridade:

1. Preço contratual específico do cliente
2. Preço contratual do grupo do cliente
3. Campanha promocional ativa
4. Preço base com desconto por volume
5. Preço base

**Cache:** preços e disponibilidade são cacheados no Redis com TTL de 15 minutos. Ao atualizar um produto no admin, o cache é invalidado imediatamente via `CatalogUpdatedEvent`.

---

### Logistics

**Transportadoras integradas:**

| Transportadora | Código | Protocolo |
|----------------|--------|-----------|
| Correios | `CORREIOS` | REST API |
| Jadlog | `JADLOG` | SOAP (legado) |
| Rapidão Cometa | `RAPIDAO` | REST API |

A seleção da transportadora é automática com base em CEP de destino, peso e dimensões do pacote, prazo de entrega desejado e menor custo para o mesmo prazo.

**Rastreamento:** eventos recebidos por webhook das transportadoras são publicados no tópico Kafka `logistics.tracking`. O frontend consome via Server-Sent Events (SSE) em `/api/v1/tracking/{orderId}/stream` para atualizações em tempo real.

**Gestão de estoque (RPI — Reserva Preventiva de Itens):**

- Reserva ocorre ao **confirmar** o pedido (não ao criar o rascunho)
- Liberação ocorre ao **cancelar**
- Estoque físico é atualizado ao **despachar**
- Alertas de reposição são enviados quando o estoque cai abaixo do `reorder_point` configurado por SKU

## ADRs

- **ADR-001** — Kafka para comunicação assíncrona entre contexts
- **ADR-002** — Cache Redis no catálogo (reduz 90% leituras no banco)
- **ADR-003** — Reserva de estoque na confirmação, não no rascunho

## Times

| Time | Canal |
|------|-------|
| Backend Core | `#nexus-backend` |
| Logística | `#nexus-logistics` |
| Frontend | `#nexus-frontend` |
| Infra | `#nexus-infra` |

**Tech Lead:** Ana Souza · **Arquiteto:** Rafael Lima · **PM:** Carlos Mendes
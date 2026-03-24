# orders-service — Contexto para IA

Bounded context de **Pedidos**. Gerencia o ciclo de vida completo de um pedido B2B, desde o rascunho até a entrega ou cancelamento.

## Responsabilidades

- Criação e gestão de pedidos
- Aplicação das regras de negócio (mínimo, desconto, cancelamento, crédito)
- Publicação de eventos Kafka para os demais contextos
- Consulta ao `CreditService` antes de confirmar pedidos

## Pacote base

```
com.techcorp.nexus.orders
├── controller/     # REST endpoints
├── service/        # Regras de negócio (OrderService, CreditService)
├── domain/
│   ├── model/      # Order, OrderItem, OrderStatus
│   └── event/      # OrderConfirmedEvent, OrderDispatchedEvent, OrderCancelledEvent
├── repository/     # OrderRepository (Spring Data JPA)
└── config/         # SecurityConfig, KafkaConfig
```

## Ciclo de vida do pedido

```
RASCUNHO → CONFIRMADO → EM_SEPARACAO → DESPACHADO → ENTREGUE
                ↓
           CANCELADO
```

Transições válidas estão encapsuladas em `OrderStatus.canTransitionTo()`. Nunca fazer transição de status diretamente — sempre passar pelo método.

## Regras de negócio

1. **Pedido mínimo** — R$ 500,00 para PJ; R$ 100,00 para PF. Validado em `Order.meetsMinimumOrder()`.
2. **Desconto por volume** — 3% automático para pedidos acima de R$ 5.000,00. Aplicado em `Order.applyVolumeDiscount()`.
3. **Limite de crédito** — `CreditService.validateCredit()` é chamado antes de confirmar. Se bloqueado, lança exceção ou envia para revisão manual.
4. **Cancelamento sem custo** — janela de 2 horas após confirmação. Após isso, taxa de 5% sobre o total. Lógica em `Order.getCancellationFee()`.
5. **Itens descontinuados** — não podem ser adicionados a novos pedidos. Validar status do produto no Catalog antes de adicionar item.

## API

| Método | Endpoint | Role mínima |
|--------|----------|-------------|
| `POST` | `/api/v1/orders` | `ROLE_BUYER` |
| `GET` | `/api/v1/orders/{id}` | `ROLE_BUYER` |
| `PUT` | `/api/v1/orders/{id}/submit` | `ROLE_BUYER` |
| `DELETE` | `/api/v1/orders/{id}` | `ROLE_BUYER` |
| `GET` | `/api/v1/orders?clientId=X` | `ROLE_BUYER` |

## Eventos Kafka publicados

| Tópico | Evento | Quando |
|--------|--------|--------|
| `orders.confirmed` | `OrderConfirmedEvent` | Ao confirmar — Logistics consome para reservar estoque (RPI) |
| `orders.dispatched` | `OrderDispatchedEvent` | Ao despachar |
| `orders.cancelled` | `OrderCancelledEvent` | Ao cancelar — Logistics consome para liberar reserva |

## Banco de dados

Schema `orders` no PostgreSQL compartilhado. Migrations em `src/main/resources/db/migration/` via Flyway. Nunca alterar arquivos `V*` já aplicados — sempre criar novo arquivo de migration.

Tabelas: `orders.orders`, `orders.order_items`.

## Observações para o agente

- `Order.applyVolumeDiscount()` deve ser chamado sempre que itens forem adicionados ou removidos
- A reserva de estoque **não** é responsabilidade deste serviço — ocorre no `logistics-service` ao consumir `OrderConfirmedEvent`
- `OrderStatus` usa switch expression (Java 14+) — manter esse padrão ao adicionar novos estados
- Usar Records para novos eventos Kafka

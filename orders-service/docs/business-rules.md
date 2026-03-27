# Orders Service — Regras de Negócio

## Ciclo de vida do pedido

```
RASCUNHO → CONFIRMADO → EM_SEPARACAO → DESPACHADO → ENTREGUE
                ↓
           CANCELADO
```

Transições válidas estão encapsuladas em `OrderStatus.canTransitionTo()`. Nunca fazer transição de status diretamente — sempre passar pelo método.

| Status | Descrição |
|--------|-----------|
| `RASCUNHO` | Criado mas não submetido. Itens podem ser alterados. |
| `CONFIRMADO` | Submetido e aprovado pelo sistema de crédito. Bloqueado para edição. |
| `EM_SEPARACAO` | Depósito iniciou a separação dos itens. |
| `DESPACHADO` | Saiu do depósito com código de rastreamento. |
| `ENTREGUE` | Confirmação de entrega recebida. |
| `CANCELADO` | Solicitado antes do despacho. Após despacho, abre-se uma devolução. |

---

## Regras

### 1. Pedido mínimo
- R$ 500,00 para clientes PJ
- R$ 100,00 para clientes PF
- Implementado em `Order.meetsMinimumOrder()`

### 2. Desconto por volume
- 3% automático para pedidos acima de R$ 5.000,00
- Implementado em `Order.applyVolumeDiscount()`
- **Deve ser chamado sempre que itens forem adicionados ou removidos**

### 3. Limite de crédito
- `CreditService.validateCredit()` é chamado antes de confirmar
- Se o cliente estiver inadimplente ou acima do limite, o pedido vai para revisão manual
- Implementado em `OrderService` no fluxo de confirmação

### 4. Prazo de cancelamento
- Até 2 horas após a confirmação: cancelamento sem custo
- Após 2 horas: taxa de 5% sobre o valor total do pedido
- Implementado em `Order.getCancellationFee()`

### 5. Itens descontinuados
- Produtos com status `DESCONTINUADO` ou `SUSPENSO` não podem ser adicionados a novos pedidos
- Pedidos existentes com esses itens não são afetados
- Validação feita consultando o `catalog-service` antes de adicionar o item

---

## Responsabilidades que NÃO são deste serviço

- **Reserva de estoque** — ocorre no `logistics-service` ao consumir `OrderConfirmedEvent` (ADR-003)
- **Resolução de preço** — delegado ao `catalog-service` via `PricingEngine`

---

## Eventos Kafka publicados

| Tópico | Evento | Quando |
|--------|--------|--------|
| `orders.confirmed` | `OrderConfirmedEvent` | Ao confirmar — Logistics consome para reservar estoque (RPI) |
| `orders.dispatched` | `OrderDispatchedEvent` | Ao despachar |
| `orders.cancelled` | `OrderCancelledEvent` | Ao cancelar — Logistics consome para liberar reserva |

---

## Banco de dados

Schema `orders` no PostgreSQL compartilhado.
Tabelas: `orders.orders`, `orders.order_items`.
Migrations em `src/main/resources/db/migration/` via Flyway. Nunca alterar arquivos `V*` já aplicados — sempre criar novo arquivo de migration.

---

## Notas de implementação

- `OrderStatus` usa switch expression (Java 14+) — manter esse padrão ao adicionar novos estados
- Usar Records para novos eventos Kafka
- `Order.applyVolumeDiscount()` deve ser chamado sempre que itens forem adicionados ou removidos

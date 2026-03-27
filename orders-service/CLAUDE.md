# orders-service — Contexto para IA

Bounded context de **Pedidos**. Gerencia o ciclo de vida completo de um pedido B2B.

> Regras de negócio detalhadas: `orders-service/docs/business-rules.md`
> API REST: `orders-service/docs/api.md`

## Responsabilidades

- Criação e gestão de pedidos
- Aplicação das regras de negócio (mínimo, desconto, cancelamento, crédito)
- Publicação de eventos Kafka para os demais contextos
- Consulta ao `CreditService` antes de confirmar pedidos

## Pacote base

```
com.rodrigomsr2.nexus.orders
├── controller/     # REST endpoints
├── service/        # Regras de negócio (OrderService, CreditService)
├── domain/
│   ├── model/      # Order, OrderItem, OrderStatus
│   └── event/      # OrderConfirmedEvent, OrderDispatchedEvent, OrderCancelledEvent
├── repository/     # OrderRepository (Spring Data JPA)
└── config/         # SecurityConfig, KafkaConfig
```

## Notas de implementação

- `OrderStatus` usa switch expression (Java 14+) — manter esse padrão ao adicionar novos estados
- Transições de status sempre via `OrderStatus.canTransitionTo()` — nunca diretamente
- Usar Records para novos eventos Kafka
- `Order.applyVolumeDiscount()` deve ser chamado sempre que itens forem adicionados ou removidos
- A reserva de estoque **não** é responsabilidade deste serviço — ocorre no `logistics-service` ao consumir `OrderConfirmedEvent` (ADR-003)

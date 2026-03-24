# logistics-service — Contexto para IA

Bounded context de **Logística**. Gerencia integração com transportadoras, rastreamento em tempo real e reserva de estoque (RPI).

## Responsabilidades

- Reserva e liberação de estoque (mecanismo RPI)
- Seleção automática de transportadora
- Integração com Correios, Jadlog e Rapidão Cometa
- Rastreamento em tempo real via SSE
- Consumo de eventos Kafka do `orders-service`

## Pacote base

```
com.techcorp.nexus.logistics
├── controller/
│   └── TrackingController.java   # SSE + webhook das transportadoras
├── service/
│   ├── ShippingSelector.java     # Seleção automática de transportadora
│   ├── InventoryService.java     # Reserva/liberação de estoque (RPI)
│   └── ShipmentService.java      # Gestão de despachos
├── adapter/                      # Integrações com transportadoras
│   ├── TransportadoraAdapter.java  # Interface
│   ├── CorreiosAdapter.java        # REST
│   ├── JadlogAdapter.java          # SOAP legado
│   └── RapidaoAdapter.java         # REST
├── domain/         # Shipment, TrackingEvent, Inventory
├── repository/     # Spring Data JPA
└── config/         # KafkaConfig, RestTemplateConfig
```

## Transportadoras

| Código | Protocolo | Observação |
|--------|-----------|------------|
| `CORREIOS` | REST | Principal fallback quando Jadlog cai |
| `JADLOG` | SOAP (legado) | Apresenta degradação em horário de pico — monitorar |
| `RAPIDAO` | REST | Melhor prazo para Sul e Sudeste |

`ShippingSelector` exclui automaticamente transportadoras com `isHealthy() == false` antes de cotar.

## Gestão de estoque — RPI (Reserva Preventiva de Itens)

| Evento | Ação no estoque |
|--------|----------------|
| `OrderConfirmedEvent` consumido | Reservar itens (`reserved += quantity`) |
| `OrderCancelledEvent` consumido | Liberar reserva (`reserved -= quantity`) |
| Pedido despachado | Baixa física (`quantity -= quantity`, `reserved -= quantity`) |
| Estoque abaixo de `reorder_point` | Disparar alerta de reposição |

**Nunca** reservar estoque no rascunho (ADR-003). A reserva ocorre exclusivamente ao consumir `OrderConfirmedEvent`.

## Rastreamento em tempo real

Fluxo: `Webhook transportadora → POST /api/v1/tracking/webhook/{carrierId} → Kafka logistics.tracking → SSE frontend`

O `TrackingController` mantém um `Map<String, SseEmitter>` com as conexões abertas. Eventos chegam via `@KafkaListener` e são repassados para o emitter correspondente ao `orderId`.

Endpoint SSE: `GET /api/v1/tracking/{orderId}/stream`

## Kafka — tópicos consumidos

| Tópico | Evento | Ação |
|--------|--------|------|
| `orders.confirmed` | `OrderConfirmedEvent` | Reservar estoque (RPI) |
| `orders.cancelled` | `OrderCancelledEvent` | Liberar reserva |

## Banco de dados

Schema `logistics` no PostgreSQL compartilhado. Tabelas: `logistics.shipments`, `logistics.tracking_events`, `logistics.inventory`.

## Observações para o agente

- Ao adicionar nova transportadora: implementar `TransportadoraAdapter`, registrar como `@Component` — o `ShippingSelector` injeta automaticamente `List<TransportadoraAdapter>`
- `JadlogAdapter` usa SOAP — não migrar para REST sem alinhamento com o time `#nexus-logistics`
- SSE: nunca usar `position: fixed` ou elementos que dependam de altura de viewport — o emitter envia chunks de texto puro
- `isHealthy()` é chamado a cada cotação — manter implementação leve (sem lógica pesada)
- Alertas de reposição devem ser configuráveis por SKU via `reorder_point` na tabela `logistics.inventory`

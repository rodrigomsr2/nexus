# logistics-service — Contexto para IA

Bounded context de **Logística**. Gerencia integração com transportadoras, rastreamento em tempo real e reserva de estoque (RPI).

> RPI (Reserva Preventiva de Itens): `logistics-service/docs/rpi.md`
> Transportadoras e rastreamento: `logistics-service/docs/carriers.md`

## Responsabilidades

- Reserva e liberação de estoque (mecanismo RPI)
- Seleção automática de transportadora
- Integração com Correios, Jadlog e Rapidão Cometa
- Rastreamento em tempo real via SSE
- Consumo de eventos Kafka do `orders-service`

## Pacote base

```
com.rodrigomsr2.nexus.logistics
├── controller/
│   └── TrackingController.java   # SSE + webhook das transportadoras
├── service/
│   ├── ShippingSelector.java     # Seleção automática de transportadora
│   ├── InventoryService.java     # Reserva/liberação de estoque (RPI)
│   └── ShipmentService.java      # Gestão de despachos
├── adapter/
│   ├── TransportadoraAdapter.java  # Interface
│   ├── CorreiosAdapter.java        # REST
│   ├── JadlogAdapter.java          # SOAP legado
│   └── RapidaoAdapter.java         # REST
├── domain/         # Shipment, TrackingEvent, Inventory
├── repository/     # Spring Data JPA
└── config/         # KafkaConfig, RestTemplateConfig
```

## Notas de implementação

- Ao adicionar nova transportadora: implementar `TransportadoraAdapter` e registrar como `@Component` — o `ShippingSelector` injeta automaticamente `List<TransportadoraAdapter>`
- `JadlogAdapter` usa SOAP — não migrar para REST sem alinhamento com o time `#nexus-logistics`
- `isHealthy()` é chamado a cada cotação — manter implementação leve (sem lógica pesada)
- SSE: `EventSource` não suporta headers — token JWT passado como query param `?token=`
- Alertas de reposição configuráveis por SKU via `reorder_point` na tabela `logistics.inventory`
- **Nunca** reservar estoque no rascunho — reserva ocorre exclusivamente ao consumir `OrderConfirmedEvent` (ADR-003)

# Logistics Service — Transportadoras

## Transportadoras integradas

| Transportadora | Código | Protocolo | Observação |
|----------------|--------|-----------|------------|
| Correios | `CORREIOS` | REST | Principal fallback quando Jadlog cai |
| Jadlog | `JADLOG` | SOAP (legado) | Apresenta degradação em horário de pico — monitorar |
| Rapidão Cometa | `RAPIDAO` | REST | Melhor prazo para Sul e Sudeste |

## Seleção automática de transportadora

O `ShippingSelector` seleciona a transportadora com base em:
1. CEP de destino
2. Peso e dimensões do pacote
3. Prazo de entrega desejado
4. Menor custo para o mesmo prazo

Transportadoras com `isHealthy() == false` são excluídas automaticamente antes de cotar. O `isHealthy()` é chamado a cada cotação — manter implementação leve, sem lógica pesada.

## Como adicionar uma nova transportadora

1. Implementar a interface `TransportadoraAdapter`
2. Registrar como `@Component`
3. O `ShippingSelector` injeta automaticamente `List<TransportadoraAdapter>` — a nova transportadora entra no processo de seleção sem outras alterações

## Rastreamento em tempo real

**Fluxo:**
```
Webhook da transportadora
  → POST /api/v1/tracking/webhook/{carrierId}
  → Kafka logistics.tracking
  → SSE frontend
```

O `TrackingController` mantém um `Map<String, SseEmitter>` com as conexões abertas. Eventos chegam via `@KafkaListener` e são repassados ao emitter correspondente ao `orderId`.

**Endpoint SSE:** `GET /api/v1/tracking/{orderId}/stream`

**Atenção:** SSE (`EventSource`) não suporta headers customizados. O token JWT é passado como query param `?token=` no endpoint de streaming.

## Observações sobre o Jadlog

- Usa SOAP (legado) — não migrar para REST sem alinhamento com o time `#nexus-logistics`
- Apresenta degradação em horário de pico — monitorar o `isHealthy()` com atenção
- `JadlogAdapter` é o único adapter que usa `RestTemplate` com conversão SOAP em vez de `WebClient`

# ADR-001 — Kafka para comunicação assíncrona entre bounded contexts

**Status:** Aceito
**Data:** 2026-03-25

## Contexto

A plataforma Nexus é composta por 3 bounded contexts independentes (Orders, Catalog, Logistics). Eventos como confirmação de pedido precisam ser comunicados do `orders-service` para o `logistics-service` para disparar a reserva de estoque (RPI). Era necessário decidir o mecanismo de comunicação entre esses contextos.

## Decisão

Usar Apache Kafka para toda comunicação **entre** bounded contexts. Comunicação **dentro** do mesmo bounded context ou via API Gateway permanece síncrona (REST).

## Tópicos definidos

| Tópico | Publicado por | Consumido por |
|--------|--------------|--------------|
| `orders.confirmed` | orders-service | logistics-service |
| `orders.dispatched` | orders-service | — |
| `orders.cancelled` | orders-service | logistics-service |
| `logistics.tracking` | logistics-service | frontend (SSE) |
| `catalog.updated` | catalog-service | catalog-service (invalidação de cache) |

## Consequências aceitas

- Comunicação entre serviços é eventual — não há garantia de consistência imediata
- Complexidade operacional maior (Kafka + Zookeeper no ambiente local)
- Necessidade de tratar idempotência nos consumers (mesmo evento pode ser entregue mais de uma vez)

## Alternativas rejeitadas

**REST síncrono entre serviços:** acoplamento direto entre contexts. Uma falha no `logistics-service` bloquearia a confirmação de pedidos no `orders-service`. Rejeitado.

**RabbitMQ:** capacidade de replay limitada. Kafka permite reprocessar eventos históricos, o que é valioso para sincronização de estado após falhas. Rejeitado.

# ADR-002 — Cache Redis no catálogo

**Status:** Aceito
**Data:** 2026-03-25

## Contexto

O `catalog-service` é o serviço mais lido da plataforma — toda adição de item a um pedido dispara uma consulta de preço via `PricingEngine`. Com múltiplos clientes e grupos de preço, cada resolução envolve até 5 consultas ao banco em ordem de prioridade. Sob carga, isso se tornaria um gargalo.

## Decisão

Cachear o resultado de `PricingEngine.resolvePrice()` no Redis com TTL de 15 minutos. Chave de cache: `pricing:<sku>:<clientId>`. Invalidação imediata ao atualizar um produto via `CatalogUpdatedEvent` no Kafka.

## Consequências aceitas

- Preços podem estar desatualizados por até 15 minutos se a invalidação falhar
- Complexidade adicional: a invalidação de cache precisa ser testada junto com qualquer mudança no `PricingEngine`
- Nunca invalidar todo o cache de uma vez — invalidar por chave específica para não causar thundering herd

## Resultado

Redução de ~90% das leituras no banco para consultas de preço.

## Alternativas rejeitadas

**Cache em memória (local):** cada instância do serviço teria seu próprio cache — inconsistência entre réplicas. Rejeitado.

**Sem cache (banco direto):** inviável sob carga. O `PricingEngine` faz até 5 queries por resolução. Rejeitado.

# Catalog Service — Regras de Negócio

## Estrutura de produto

Cada produto possui:
- **SKU** — formato `NX-PRD-XXXXX`
- **Categoria** — hierarquia de até 3 níveis
- **Preço base**
- **Preço contratual** — por cliente (`client_id`) ou grupo (`group_id`)
- **Status** — `ATIVO`, `DESCONTINUADO`, `SUSPENSO`

## Status de produto

| Status | Comportamento |
|--------|--------------|
| `ATIVO` | Disponível para novos pedidos |
| `DESCONTINUADO` | Não pode ser adicionado a novos pedidos. Pedidos existentes não são afetados. |
| `SUSPENSO` | Não disponível temporariamente. Mesmo comportamento do DESCONTINUADO para novos pedidos. |

**Nunca deletar um produto** — apenas mudar o status. Produtos descontinuados podem existir em pedidos antigos.

## Cache Redis

- TTL: 15 minutos
- Chave: `pricing:<sku>:<clientId>`
- Invalidação imediata ao atualizar produto no admin — publicar `CatalogUpdatedEvent` no Kafka
- Consumers do evento chamam `cacheManager.getCache("pricing").evict(key)`
- **Nunca invalidar todo o cache de uma vez** — invalidar por chave específica para evitar thundering herd

## Banco de dados

Schema `catalog` no PostgreSQL compartilhado.
Tabelas: `catalog.products`, `catalog.contract_prices`, `catalog.campaigns`.

## Notas de implementação

- `PricingEngine` é o método mais crítico — qualquer alteração requer testes de regressão completos
- O `@Cacheable` está em `PricingEngine.resolvePrice()` — não duplicar cache em outros métodos
- Ao adicionar novo nível de prioridade de preço, atualizar também o `catalog-service/docs/pricing-engine.md` e o `CLAUDE.md` raiz

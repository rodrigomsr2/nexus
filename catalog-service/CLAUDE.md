# catalog-service — Contexto para IA

Bounded context de **Catálogo**. Gerencia produtos, precificação e regras comerciais. É o serviço mais lido da plataforma — toda adição de item a um pedido passa por aqui.

## Responsabilidades

- CRUD de produtos e categorias
- Resolução de preço via `PricingEngine`
- Gestão de preços contratuais por cliente e grupo
- Gestão de campanhas promocionais
- Cache de preços e disponibilidade no Redis

## Pacote base

```
com.techcorp.nexus.catalog
├── controller/     # REST endpoints
├── service/
│   ├── PricingEngine.java        # Resolução de preço (núcleo do serviço)
│   ├── ContractPriceService.java # Preços contratuais
│   ├── CampaignService.java      # Campanhas promocionais
│   └── ProductService.java       # CRUD de produtos
├── domain/         # Product, ContractPrice, Campaign
├── repository/     # Spring Data JPA
└── config/         # CacheConfig (Redis), SecurityConfig
```

## PricingEngine — ordem de prioridade

Sempre respeitar esta ordem ao modificar a lógica de precificação:

1. Preço contratual específico do cliente (`client_id`)
2. Preço contratual do grupo do cliente (`group_id`)
3. Campanha promocional ativa (verificar `starts_at` e `ends_at`)
4. Preço base com desconto por volume (aplicado no `orders-service`)
5. Preço base do produto

O resultado é cacheado com `@Cacheable(value = "pricing", key = "#sku + ':' + #clientId")`.

## Cache Redis

- TTL: 15 minutos
- Invalidação imediata ao atualizar produto no admin — publicar `CatalogUpdatedEvent` no Kafka
- Consumers do evento devem chamar `cacheManager.getCache("pricing").evict(key)`
- Nunca invalidar todo o cache de uma vez — invalidar por chave específica

## Status de produto

| Status | Comportamento |
|--------|--------------|
| `ATIVO` | Disponível para novos pedidos |
| `DESCONTINUADO` | Não pode ser adicionado a novos pedidos. Pedidos existentes não são afetados. |
| `SUSPENSO` | Não disponível temporariamente. Mesmo comportamento do DESCONTINUADO para novos pedidos. |

## Banco de dados

Schema `catalog` no PostgreSQL compartilhado. Tabelas: `catalog.products`, `catalog.contract_prices`, `catalog.campaigns`.

## Observações para o agente

- `PricingEngine` é o método mais crítico do serviço — qualquer alteração requer testes de regressão completos
- O cache `@Cacheable` está em `PricingEngine.resolvePrice()` — não duplicar cache em outros métodos
- Ao adicionar novo nível de prioridade de preço, atualizar também a documentação do `CLAUDE.md` raiz e o README
- Produtos `DESCONTINUADO` podem ainda existir em pedidos antigos — nunca deletar, apenas mudar status

# PricingEngine — Resolução de Preço

O `PricingEngine` é o núcleo do `catalog-service`. Resolve o preço final de um produto para um cliente específico, considerando preços contratuais, campanhas e descontos.

## Ordem de prioridade

Sempre respeitar esta ordem ao modificar a lógica de precificação:

1. **Preço contratual específico do cliente** (`client_id`)
2. **Preço contratual do grupo do cliente** (`group_id`)
3. **Campanha promocional ativa** (verificar `starts_at` e `ends_at`)
4. **Preço base com desconto por volume** (aplicado no `orders-service`)
5. **Preço base do produto**

O resultado é cacheado com:
```java
@Cacheable(value = "pricing", key = "#sku + ':' + #clientId")
```

## Fluxo de invalidação de cache

Ao atualizar um produto no admin:
1. `ProductService` persiste a mudança no banco
2. Publica `CatalogUpdatedEvent` no Kafka com o SKU afetado
3. Consumer do evento chama `cacheManager.getCache("pricing").evict(key)` para cada `clientId` afetado

**Atenção:** invalidar por chave específica (`sku:clientId`), nunca o cache inteiro.

## Regras de campanha

- Uma campanha é válida se `now` está entre `starts_at` e `ends_at`
- Se houver mais de uma campanha ativa para o mesmo produto, usar a de maior desconto
- Campanhas não se acumulam com preços contratuais — preço contratual tem prioridade

## Regras de desconto por volume

O desconto por volume é calculado no `orders-service` (`Order.applyVolumeDiscount()`), não aqui. O `PricingEngine` retorna o preço unitário; o desconto global do pedido é aplicado depois.

## Classes envolvidas

| Classe | Responsabilidade |
|--------|-----------------|
| `PricingEngine` | Orquestra a resolução de preço na ordem de prioridade |
| `ContractPriceService` | Consulta preços contratuais por `client_id` e `group_id` |
| `CampaignService` | Verifica campanhas ativas por SKU e período |
| `ProductService` | CRUD de produtos e publicação de `CatalogUpdatedEvent` |

## Atenção ao testar

Qualquer alteração no `PricingEngine` requer testes de regressão cobrindo todas as 5 prioridades, incluindo casos de sobreposição (ex: cliente com preço contratual **e** campanha ativa — contratual deve vencer).

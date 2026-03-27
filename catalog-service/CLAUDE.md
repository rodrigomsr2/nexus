# catalog-service — Contexto para IA

Bounded context de **Catálogo**. Gerencia produtos, precificação e regras comerciais. É o serviço mais lido da plataforma — toda adição de item a um pedido passa por aqui.

> Regras de negócio: `catalog-service/docs/business-rules.md`
> PricingEngine (núcleo do serviço): `catalog-service/docs/pricing-engine.md`

## Responsabilidades

- CRUD de produtos e categorias
- Resolução de preço via `PricingEngine`
- Gestão de preços contratuais por cliente e grupo
- Gestão de campanhas promocionais
- Cache de preços e disponibilidade no Redis

## Pacote base

```
com.rodrigomsr2.nexus.catalog
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

## Notas de implementação

- `PricingEngine` é o método mais crítico — qualquer alteração requer testes de regressão completos
- O `@Cacheable` está em `PricingEngine.resolvePrice()` — não duplicar cache em outros métodos
- Ao adicionar novo nível de prioridade de preço, atualizar `catalog-service/docs/pricing-engine.md` e o `CLAUDE.md` raiz
- Nunca deletar produtos — apenas mudar status

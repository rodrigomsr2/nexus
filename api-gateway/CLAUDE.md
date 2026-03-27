# api-gateway — Contexto para IA

Único ponto de entrada externo da plataforma. Baseado em **Spring Cloud Gateway**. Não contém lógica de negócio — responsável exclusivamente por roteamento, autenticação, rate limiting e circuit breaking.

## Responsabilidades

- Validação de token JWT (Keycloak)
- Roteamento para os microsserviços internos
- Rate limiting via Redis
- Circuit breaker por rota (Resilience4j)
- CORS para o frontend

## Rotas configuradas

| Rota | Serviço destino | Path |
|------|----------------|------|
| orders | orders-service:8080 | `/api/v1/orders/**` |
| catalog | catalog-service:8080 | `/api/v1/catalog/**`, `/api/v1/products/**`, `/api/v1/pricing/**` |
| logistics | logistics-service:8080 | `/api/v1/tracking/**`, `/api/v1/shipping/**` |

Toda configuração de rotas em `src/main/resources/application.yml`. Preferir configuração declarativa no YAML em vez de beans Java para rotas simples.

## Rate limiting

Configurado via Redis com `RequestRateLimiter`:
- 100 requisições/segundo por rota (`replenishRate`)
- Burst de até 200 requisições (`burstCapacity`)

## Circuit Breaker

Resilience4j — instâncias: `ordersCircuitBreaker`, `catalogCircuitBreaker`, `logisticsCircuitBreaker`. Abre após 50% de falhas em janela de 10 requisições. Fallback via `/fallback/{servico}`.

## Autenticação

Valida a assinatura JWT via `spring.security.oauth2.resourceserver.jwt.issuer-uri`. Após validação, propaga o token para os serviços downstream — cada serviço faz sua própria verificação de roles via `@PreAuthorize`.

## Notas de implementação

- Este serviço **não** deve conter lógica de negócio
- Ao adicionar nova rota, adicionar também o circuit breaker correspondente
- CORS configurado para `localhost:3000` em dev — para produção, atualizar `FRONTEND_URL` via variável de ambiente
- O gateway não tem banco de dados próprio — usa apenas Redis (rate limiting)

# Orders Service — API REST

Base URL (via API Gateway): `http://localhost:8080/api/v1/orders`

## Endpoints

| Método | Endpoint | Role mínima | Descrição |
|--------|----------|-------------|-----------|
| `POST` | `/api/v1/orders` | `ROLE_BUYER` | Cria rascunho |
| `GET` | `/api/v1/orders/{id}` | `ROLE_BUYER` | Detalha pedido |
| `PUT` | `/api/v1/orders/{id}/submit` | `ROLE_BUYER` | Confirma pedido |
| `DELETE` | `/api/v1/orders/{id}` | `ROLE_BUYER` | Cancela pedido |
| `GET` | `/api/v1/orders?clientId=X` | `ROLE_BUYER` | Lista pedidos do cliente |

## Exemplos

### Criar rascunho

```bash
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "client-001",
    "clientType": "PJ",
    "items": [
      { "sku": "NX-PRD-00001", "quantity": 2 },
      { "sku": "NX-PRD-00003", "quantity": 5 }
    ]
  }'
```

### Confirmar pedido

```bash
curl -X PUT http://localhost:8080/api/v1/orders/{id}/submit \
  -H "Authorization: Bearer $TOKEN"
```

### Cancelar pedido

```bash
curl -X DELETE http://localhost:8080/api/v1/orders/{id} \
  -H "Authorization: Bearer $TOKEN"
```

## Autenticação

Token JWT obtido via Keycloak:

```bash
curl -X POST http://localhost:8180/realms/nexus/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=nexus-backend" \
  -d "username=admin@nexus.local" \
  -d "password=admin123"
```

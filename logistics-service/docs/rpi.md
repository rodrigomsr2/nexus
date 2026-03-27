# Logistics Service — RPI (Reserva Preventiva de Itens)

Mecanismo de gestão de estoque do `logistics-service`. A reserva é acionada por eventos Kafka do `orders-service`.

## Fluxo de estoque

| Evento / Ação | Operação no estoque |
|--------------|---------------------|
| `OrderConfirmedEvent` consumido | `reserved += quantity` |
| `OrderCancelledEvent` consumido | `reserved -= quantity` |
| Pedido despachado | Baixa física: `quantity -= quantity` e `reserved -= quantity` |
| Estoque abaixo de `reorder_point` | Dispara alerta de reposição |

## Regra fundamental (ADR-003)

**Nunca reservar estoque no rascunho.** A reserva ocorre exclusivamente ao consumir `OrderConfirmedEvent`. O rascunho não gera nenhuma operação de estoque.

## Race condition

Dois pedidos confirmados simultaneamente para o mesmo SKU podem tentar reservar mais do que o disponível. Mitigação: usar `SELECT FOR UPDATE` na tabela `logistics.inventory` ao atualizar a reserva.

## Alertas de reposição

- Configurável por SKU via campo `reorder_point` na tabela `logistics.inventory`
- Alerta disparado quando `quantity - reserved <= reorder_point`
- Implementado em `InventoryService`

## Tópicos Kafka consumidos

| Tópico | Evento | Ação |
|--------|--------|------|
| `orders.confirmed` | `OrderConfirmedEvent` | Reservar estoque |
| `orders.cancelled` | `OrderCancelledEvent` | Liberar reserva |

## Banco de dados

Tabela: `logistics.inventory`

| Coluna | Descrição |
|--------|-----------|
| `sku` | Identificador do produto |
| `quantity` | Estoque físico total |
| `reserved` | Quantidade reservada (pedidos confirmados não despachados) |
| `reorder_point` | Nível mínimo antes de alertar reposição |

Estoque disponível efetivo: `quantity - reserved`

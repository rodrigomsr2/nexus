# ADR-003 — Reserva de estoque na confirmação do pedido, não no rascunho

**Status:** Aceito
**Data:** 2026-03-25

## Contexto

O ciclo de vida do pedido começa com um `RASCUNHO`, que pode ser editado livremente antes de ser submetido. Era necessário decidir em qual momento o estoque é reservado: ao criar o rascunho ou ao confirmar o pedido.

## Decisão

A reserva de estoque (RPI — Reserva Preventiva de Itens) ocorre **exclusivamente ao confirmar o pedido** — quando o `logistics-service` consome o `OrderConfirmedEvent`. O rascunho não reserva nada.

Fluxo:
- `OrderConfirmedEvent` consumido → `reserved += quantity`
- `OrderCancelledEvent` consumido → `reserved -= quantity`
- Pedido despachado → baixa física (`quantity -= quantity`, `reserved -= quantity`)

## Consequências aceitas

- Risco de race condition: dois pedidos confirmados simultaneamente para o mesmo SKU podem reservar mais do que o disponível. Mitigado com `SELECT FOR UPDATE` na tabela de inventário.
- Estoque aparente durante o rascunho não reflete reservas — o cliente pode criar um rascunho com itens que serão confirmados por outro cliente antes.

## Alternativas rejeitadas

**Reservar no rascunho:** rascunhos são editáveis e frequentemente abandonados. Reservar no rascunho bloquearia estoque para pedidos que nunca serão confirmados, prejudicando disponibilidade. Rejeitado.

**Reservar ao submeter, liberar se crédito reprovado:** mais complexo — exigiria compensação em caso de reprovação de crédito. A confirmação já inclui a validação de crédito, então reservar após a confirmação é mais simples e correto. Rejeitado.

# frontend — Contexto para IA

SPA React 18 + TypeScript + Vite. Interface do operador B2B para gestão de pedidos, catálogo e rastreamento.

## Stack

- **React 18** + **TypeScript**
- **Vite** (bundler)
- **React Query** (`@tanstack/react-query`) — cache e sincronização de estado servidor
- **Zustand** — estado global do cliente (auth, preferências)
- **React Hook Form** + **Zod** — formulários e validação
- **Recharts** — gráficos e dashboards
- **Tailwind CSS** — estilização

## Estrutura

```
src/
├── components/
│   ├── orders/       # Componentes do bounded context Orders
│   ├── catalog/      # Componentes do bounded context Catalog
│   ├── logistics/    # Componentes do bounded context Logistics
│   └── layout/       # Sidebar, Topbar, etc.
├── pages/            # Páginas (roteadas pelo React Router)
├── services/
│   └── ordersApi.ts  # Chamadas HTTP + SSE (axios + EventSource)
├── hooks/            # Custom hooks por feature
└── types/            # Tipos TypeScript globais
```

## Comunicação com a API

Todas as chamadas passam pelo API Gateway em `VITE_API_BASE_URL` (default `http://localhost:8080`). Token JWT armazenado no `localStorage` como `nexus_token` e injetado automaticamente pelo interceptor do axios.

Para rastreamento em tempo real usar `subscribeTracking()` de `ordersApi.ts` — abre conexão SSE com `GET /api/v1/tracking/{orderId}/stream`.

## Variáveis de ambiente

| Variável | Descrição | Default |
|----------|-----------|---------|
| `VITE_API_BASE_URL` | URL do API Gateway | `http://localhost:8080` |

Arquivo `.env.local` para desenvolvimento local (não commitar).

## Desenvolvimento local

```bash
npm install
echo "VITE_API_BASE_URL=http://localhost:8080" > .env.local
npm run dev   # http://localhost:3000
```

## Notas de implementação

- Usar React Query para todo estado que vem da API — evitar `useEffect` + `fetch` manual
- Formulários sempre com React Hook Form + Zod — nunca validação manual inline
- Componentes por bounded context — não misturar lógica de Orders com Catalog no mesmo componente
- SSE (`EventSource`) não suporta headers customizados — token JWT passado como query param `?token=`
- Em produção o nginx faz proxy para o gateway — não há CORS em produção

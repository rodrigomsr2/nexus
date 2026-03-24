import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080',
});

// Injeta token JWT automaticamente em todas as requisições
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('nexus_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Redireciona para login em caso de 401
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('nexus_token');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

// ─── Types ───────────────────────────────────────────────

export type OrderStatus =
  | 'RASCUNHO'
  | 'CONFIRMADO'
  | 'EM_SEPARACAO'
  | 'DESPACHADO'
  | 'ENTREGUE'
  | 'CANCELADO';

export interface OrderItem {
  id: string;
  sku: string;
  productName: string;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
}

export interface Order {
  id: string;
  orderNumber: string;
  clientId: string;
  clientType: 'PJ' | 'PF';
  status: OrderStatus;
  items: OrderItem[];
  subtotal: number;
  discountPercent: number;
  total: number;
  trackingCode?: string;
  carrierId?: string;
  createdAt: string;
  updatedAt: string;
  confirmedAt?: string;
  dispatchedAt?: string;
  deliveredAt?: string;
}

export interface CreateOrderPayload {
  clientId: string;
  clientType: 'PJ' | 'PF';
  items: { sku: string; quantity: number }[];
}

// ─── API calls ───────────────────────────────────────────

/** POST /api/v1/orders — cria rascunho */
export const createOrder = (payload: CreateOrderPayload) =>
  api.post<Order>('/api/v1/orders', payload).then((r) => r.data);

/** GET /api/v1/orders/{id} */
export const getOrder = (id: string) =>
  api.get<Order>(`/api/v1/orders/${id}`).then((r) => r.data);

/** PUT /api/v1/orders/{id}/submit — confirma pedido */
export const submitOrder = (id: string) =>
  api.put<Order>(`/api/v1/orders/${id}/submit`).then((r) => r.data);

/** DELETE /api/v1/orders/{id} — cancela pedido */
export const cancelOrder = (id: string) =>
  api.delete<Order>(`/api/v1/orders/${id}`).then((r) => r.data);

/** GET /api/v1/orders?clientId=X */
export const listOrders = (clientId: string) =>
  api.get<Order[]>('/api/v1/orders', { params: { clientId } }).then((r) => r.data);

// ─── SSE Tracking ────────────────────────────────────────

/** Abre conexão SSE para rastreamento em tempo real */
export const subscribeTracking = (
  orderId: string,
  onEvent: (event: { status: string; description: string; location: string }) => void
): EventSource => {
  const token = localStorage.getItem('nexus_token');
  const url = `${import.meta.env.VITE_API_BASE_URL}/api/v1/tracking/${orderId}/stream?token=${token}`;
  const es = new EventSource(url);
  es.addEventListener('tracking', (e) => {
    onEvent(JSON.parse(e.data));
  });
  return es;
};

export default api;

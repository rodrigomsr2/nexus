-- V1__create_orders_schema.sql
-- Nexus Orders Schema

CREATE TABLE orders (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number     VARCHAR(20)    NOT NULL UNIQUE,
    client_id        VARCHAR(100)   NOT NULL,
    client_type      VARCHAR(10)    NOT NULL CHECK (client_type IN ('PJ', 'PF')),
    status           VARCHAR(20)    NOT NULL DEFAULT 'RASCUNHO',
    subtotal         NUMERIC(15,2),
    discount_percent NUMERIC(5,2)   DEFAULT 0,
    total            NUMERIC(15,2),
    tracking_code    VARCHAR(50),
    carrier_id       VARCHAR(20),
    created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    confirmed_at     TIMESTAMPTZ,
    dispatched_at    TIMESTAMPTZ,
    delivered_at     TIMESTAMPTZ
);

CREATE TABLE order_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID           NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    sku          VARCHAR(50)    NOT NULL,
    product_name VARCHAR(255)   NOT NULL,
    quantity     INTEGER        NOT NULL CHECK (quantity > 0),
    unit_price   NUMERIC(15,2)  NOT NULL,
    line_total   NUMERIC(15,2)
);

CREATE INDEX idx_orders_client_id    ON orders(client_id);
CREATE INDEX idx_orders_status       ON orders(status);
CREATE INDEX idx_orders_created_at   ON orders(created_at DESC);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_sku      ON order_items(sku);

-- Trigger para updated_at automático
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Nexus Platform — Database Init
-- Executado uma vez pelo Postgres na criação do container

-- Schemas por bounded context
CREATE SCHEMA IF NOT EXISTS orders;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS logistics;

-- Extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- busca textual

-- Orders schema
CREATE TABLE IF NOT EXISTS orders.orders (
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

CREATE TABLE IF NOT EXISTS orders.order_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID           NOT NULL REFERENCES orders.orders(id) ON DELETE CASCADE,
    sku          VARCHAR(50)    NOT NULL,
    product_name VARCHAR(255)   NOT NULL,
    quantity     INTEGER        NOT NULL CHECK (quantity > 0),
    unit_price   NUMERIC(15,2)  NOT NULL,
    line_total   NUMERIC(15,2)
);

-- Catalog schema
CREATE TABLE IF NOT EXISTS catalog.products (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku          VARCHAR(50)    NOT NULL UNIQUE,
    name         VARCHAR(255)   NOT NULL,
    description  TEXT,
    category_l1  VARCHAR(100),
    category_l2  VARCHAR(100),
    category_l3  VARCHAR(100),
    base_price   NUMERIC(15,2)  NOT NULL,
    status       VARCHAR(20)    NOT NULL DEFAULT 'ATIVO' CHECK (status IN ('ATIVO','DESCONTINUADO','SUSPENSO')),
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS catalog.contract_prices (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku         VARCHAR(50)    NOT NULL,
    client_id   VARCHAR(100),
    group_id    VARCHAR(100),
    price       NUMERIC(15,2)  NOT NULL,
    valid_from  DATE           NOT NULL,
    valid_until DATE,
    CONSTRAINT chk_client_or_group CHECK (client_id IS NOT NULL OR group_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS catalog.campaigns (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(100)   NOT NULL,
    sku             VARCHAR(50)    NOT NULL,
    discount_type   VARCHAR(20)    NOT NULL CHECK (discount_type IN ('PERCENT','FIXED')),
    discount_value  NUMERIC(10,2)  NOT NULL,
    starts_at       TIMESTAMPTZ    NOT NULL,
    ends_at         TIMESTAMPTZ    NOT NULL
);

-- Logistics schema
CREATE TABLE IF NOT EXISTS logistics.shipments (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id       UUID           NOT NULL,
    carrier_id     VARCHAR(20)    NOT NULL,
    tracking_code  VARCHAR(100),
    status         VARCHAR(30)    NOT NULL DEFAULT 'AGUARDANDO_DESPACHO',
    cep_destino    VARCHAR(10),
    weight_kg      NUMERIC(8,3),
    created_at     TIMESTAMPTZ    NOT NULL DEFAULT now(),
    dispatched_at  TIMESTAMPTZ,
    delivered_at   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS logistics.tracking_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID           NOT NULL REFERENCES logistics.shipments(id),
    status      VARCHAR(50)    NOT NULL,
    description TEXT,
    location    VARCHAR(100),
    occurred_at TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS logistics.inventory (
    sku             VARCHAR(50)    PRIMARY KEY,
    quantity        INTEGER        NOT NULL DEFAULT 0,
    reserved        INTEGER        NOT NULL DEFAULT 0,
    reorder_point   INTEGER        NOT NULL DEFAULT 10,
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_orders_client    ON orders.orders(client_id);
CREATE INDEX idx_orders_status    ON orders.orders(status);
CREATE INDEX idx_products_sku     ON catalog.products(sku);
CREATE INDEX idx_products_status  ON catalog.products(status);
CREATE INDEX idx_contract_sku     ON catalog.contract_prices(sku);
CREATE INDEX idx_shipments_order  ON logistics.shipments(order_id);
CREATE INDEX idx_tracking_ship    ON logistics.tracking_events(shipment_id);

-- Seed data
INSERT INTO catalog.products (sku, name, category_l1, category_l2, base_price, status) VALUES
  ('NX-PRD-00001', 'Notebook Dell XPS 13', 'Eletrônicos', 'Computadores', 6499.90, 'ATIVO'),
  ('NX-PRD-00002', 'Monitor LG 27" 4K',   'Eletrônicos', 'Monitores',    2899.90, 'ATIVO'),
  ('NX-PRD-00003', 'Teclado Mecânico Keychron', 'Periféricos', 'Teclados', 599.90, 'ATIVO'),
  ('NX-PRD-00004', 'Mouse Logitech MX Master', 'Periféricos', 'Mouses',   399.90, 'ATIVO'),
  ('NX-PRD-00005', 'Hub USB-C 7 portas',  'Periféricos', 'Hubs',         189.90, 'SUSPENSO');

INSERT INTO logistics.inventory (sku, quantity, reorder_point) VALUES
  ('NX-PRD-00001', 50,  5),
  ('NX-PRD-00002', 30,  5),
  ('NX-PRD-00003', 120, 20),
  ('NX-PRD-00004', 85,  15),
  ('NX-PRD-00005', 0,   10);

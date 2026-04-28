-- ============================================================
-- Invoice & POS Billing — PostgreSQL Schema
-- Run once: psql -U postgres -d invoice_pos -f schema.sql
-- Or automatically via: npm run migrate
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── updated_at auto-update trigger ──────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─── USERS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  email       VARCHAR(255) NOT NULL UNIQUE,
  password    VARCHAR(255) NOT NULL,
  role        VARCHAR(50)  NOT NULL DEFAULT 'cashier' CHECK (role IN ('admin','cashier','viewer')),
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  shop_name   VARCHAR(255) NOT NULL DEFAULT 'My Shop',
  phone       VARCHAR(50),
  address     TEXT,
  last_login  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── PRODUCTS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            VARCHAR(255) NOT NULL,
  sku             VARCHAR(100),
  barcode         VARCHAR(100),
  category        VARCHAR(100) NOT NULL DEFAULT 'General',
  description     TEXT,
  purchase_price  NUMERIC(12,2) NOT NULL CHECK (purchase_price >= 0),
  selling_price   NUMERIC(12,2) NOT NULL CHECK (selling_price >= 0),
  quantity        INTEGER       NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  min_stock_level INTEGER       NOT NULL DEFAULT 5,
  unit            VARCHAR(50)   NOT NULL DEFAULT 'pcs',
  image_url       TEXT,
  is_active       BOOLEAN       NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_products_user ON products(user_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(user_id, category);

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── CUSTOMERS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            VARCHAR(255)  NOT NULL,
  phone           VARCHAR(50),
  email           VARCHAR(255),
  address         TEXT,
  opening_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
  current_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes           TEXT,
  is_active       BOOLEAN       NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_customers_user ON customers(user_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(user_id, phone);

DROP TRIGGER IF EXISTS trg_customers_updated_at ON customers;
CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── SUPPLIERS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS suppliers (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            VARCHAR(255)  NOT NULL,
  phone           VARCHAR(50),
  email           VARCHAR(255),
  address         TEXT,
  company         VARCHAR(255),
  opening_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
  current_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes           TEXT,
  is_active       BOOLEAN       NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_suppliers_user ON suppliers(user_id);

DROP TRIGGER IF EXISTS trg_suppliers_updated_at ON suppliers;
CREATE TRIGGER trg_suppliers_updated_at
  BEFORE UPDATE ON suppliers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── SALES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sales (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invoice_number  VARCHAR(100)  UNIQUE,
  customer_id     UUID          REFERENCES customers(id) ON DELETE SET NULL,
  customer_name   VARCHAR(255),
  sub_total       NUMERIC(12,2) NOT NULL,
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
  grand_total     NUMERIC(12,2) NOT NULL,
  paid_amount     NUMERIC(12,2) NOT NULL DEFAULT 0,
  due_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_method  VARCHAR(50)   NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash','card','bank','credit')),
  payment_status  VARCHAR(50)   NOT NULL DEFAULT 'paid' CHECK (payment_status IN ('paid','partial','unpaid')),
  notes           TEXT,
  sale_date       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  sync_id         VARCHAR(100)  UNIQUE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sales_user_date ON sales(user_id, sale_date DESC);
CREATE INDEX IF NOT EXISTS idx_sales_customer  ON sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_sync_id   ON sales(sync_id);

DROP TRIGGER IF EXISTS trg_sales_updated_at ON sales;
CREATE TRIGGER trg_sales_updated_at
  BEFORE UPDATE ON sales
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── SALE ITEMS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sale_items (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id        UUID          NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id     UUID          REFERENCES products(id) ON DELETE SET NULL,
  product_name   VARCHAR(255)  NOT NULL,
  quantity       INTEGER       NOT NULL CHECK (quantity > 0),
  purchase_price NUMERIC(12,2) NOT NULL,
  selling_price  NUMERIC(12,2) NOT NULL,
  discount       NUMERIC(12,2) NOT NULL DEFAULT 0,
  total          NUMERIC(12,2) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);

-- ─── PURCHASES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS purchases (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purchase_number VARCHAR(100)  UNIQUE,
  supplier_id     UUID          REFERENCES suppliers(id) ON DELETE SET NULL,
  supplier_name   VARCHAR(255),
  total_amount    NUMERIC(12,2) NOT NULL,
  paid_amount     NUMERIC(12,2) NOT NULL DEFAULT 0,
  due_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_status  VARCHAR(50)   NOT NULL DEFAULT 'paid' CHECK (payment_status IN ('paid','partial','unpaid')),
  notes           TEXT,
  purchase_date   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  sync_id         VARCHAR(100)  UNIQUE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_purchases_user_date ON purchases(user_id, purchase_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchases_sync_id   ON purchases(sync_id);

DROP TRIGGER IF EXISTS trg_purchases_updated_at ON purchases;
CREATE TRIGGER trg_purchases_updated_at
  BEFORE UPDATE ON purchases
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── PURCHASE ITEMS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS purchase_items (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id  UUID          NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  product_id   UUID          REFERENCES products(id) ON DELETE SET NULL,
  product_name VARCHAR(255)  NOT NULL,
  quantity     INTEGER       NOT NULL CHECK (quantity > 0),
  cost_price   NUMERIC(12,2) NOT NULL,
  total        NUMERIC(12,2) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items(purchase_id);

-- ─── EXPENSES ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expenses (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title          VARCHAR(255)  NOT NULL,
  category       VARCHAR(100)  NOT NULL DEFAULT 'General',
  amount         NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  description    TEXT,
  expense_date   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  payment_method VARCHAR(50)   NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash','card','bank')),
  sync_id        VARCHAR(100)  UNIQUE,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON expenses(user_id, expense_date DESC);

DROP TRIGGER IF EXISTS trg_expenses_updated_at ON expenses;
CREATE TRIGGER trg_expenses_updated_at
  BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── PAYMENTS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type           VARCHAR(50)   NOT NULL CHECK (type IN ('customer','supplier')),
  customer_id    UUID          REFERENCES customers(id) ON DELETE SET NULL,
  supplier_id    UUID          REFERENCES suppliers(id) ON DELETE SET NULL,
  sale_id        UUID          REFERENCES sales(id) ON DELETE SET NULL,
  purchase_id    UUID          REFERENCES purchases(id) ON DELETE SET NULL,
  amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  payment_method VARCHAR(50)   NOT NULL DEFAULT 'cash',
  notes          TEXT,
  payment_date   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  sync_id        VARCHAR(100)  UNIQUE,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id, payment_date DESC);

-- ─── APP VERSIONS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app_versions (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  platform        VARCHAR(50)  NOT NULL CHECK (platform IN ('android','windows','all')),
  version         VARCHAR(50)  NOT NULL,
  min_version     VARCHAR(50),
  download_url    TEXT,
  release_notes   TEXT,
  is_force_update BOOLEAN      NOT NULL DEFAULT false,
  is_active       BOOLEAN      NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

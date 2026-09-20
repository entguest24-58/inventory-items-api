CREATE TABLE IF NOT EXISTS items (
  id          SERIAL PRIMARY KEY,
  name        TEXT        NOT NULL,
  sku         TEXT        NOT NULL UNIQUE,
  quantity    INTEGER     NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  price_cents INTEGER     NOT NULL CHECK (price_cents >= 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

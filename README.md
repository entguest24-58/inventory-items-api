# inventory-items-api

A small inventory service: one resource (`items`) with create / read / update / delete over HTTP.
Node 20 · TypeScript · Express · PostgreSQL.

## Run

```bash
cp .env.example .env          # DATABASE_URL, PORT
npm install
npm run build
npm start                     # applies db/schema.sql, then listens on $PORT (default 3000)
```

The service needs a reachable PostgreSQL database; `db/schema.sql` is applied at startup and is idempotent.

`GET /health` returns `{"status":"ok"}` once the database answers.

## API

All bodies are JSON. An item looks like:

```json
{ "id": 1, "name": "Widget", "sku": "WID-001", "quantity": 5, "price_cents": 1299,
  "created_at": "2026-09-19T10:00:00.000Z", "updated_at": "2026-09-19T10:00:00.000Z" }
```

| Method | Path | Success | Errors |
|---|---|---|---|
| `GET` | `/items` | `200` array of items | |
| `GET` | `/items/{id}` | `200` item | `400` id not a positive integer · `404` `{"error":"item not found"}` |
| `POST` | `/items` | `201` created item | `400` validation (`name`, `sku` required; `quantity` ≥ 0 integer, default 0; `price_cents` ≥ 0 integer) · `409` duplicate `sku` |
| `PUT` | `/items/{id}` | `200` updated item | `400` validation · `404` unknown id · `409` duplicate `sku` |
| `DELETE` | `/items/{id}` | `204` | `400` invalid id · `404` unknown id |

Malformed JSON → `400 {"error":"invalid JSON body"}`. Unknown routes → `404 {"error":"route not found"}`.

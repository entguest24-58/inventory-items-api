import { pool } from '../db';

export interface Item {
  id: number;
  name: string;
  sku: string;
  quantity: number;
  price_cents: number;
  created_at: string;
  updated_at: string;
}

export interface NewItem {
  name: string;
  sku: string;
  quantity: number;
  price_cents: number;
}

const COLUMNS = 'id, name, sku, quantity, price_cents, created_at, updated_at';

export async function listItems(): Promise<Item[]> {
  const { rows } = await pool.query<Item>(`SELECT ${COLUMNS} FROM items ORDER BY id`);
  return rows;
}

export async function getItem(id: number): Promise<Item | null> {
  const { rows } = await pool.query<Item>(`SELECT ${COLUMNS} FROM items WHERE id = $1`, [id]);
  return rows[0] ?? null;
}

export async function createItem(input: NewItem): Promise<Item> {
  const { rows } = await pool.query<Item>(
    `INSERT INTO items (name, sku, quantity, price_cents)
     VALUES ($1, $2, $3, $4)
     RETURNING ${COLUMNS}`,
    [input.name, input.sku, input.quantity, input.price_cents]
  );
  return rows[0];
}

export async function updateItem(id: number, input: NewItem): Promise<Item | null> {
  const { rows } = await pool.query<Item>(
    `UPDATE items
        SET name = $2, sku = $3, quantity = $4, price_cents = $5, updated_at = now()
      WHERE id = $1
      RETURNING ${COLUMNS}`,
    [id, input.name, input.sku, input.quantity, input.price_cents]
  );
  return rows[0] ?? null;
}

export async function deleteItem(id: number): Promise<boolean> {
  const result = await pool.query('DELETE FROM items WHERE id = $1', [id]);
  return (result.rowCount ?? 0) > 0;
}

export function isUniqueViolation(err: unknown): boolean {
  return typeof err === 'object' && err !== null && (err as { code?: string }).code === '23505';
}

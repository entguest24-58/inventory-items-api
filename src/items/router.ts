import { Router, Request, Response } from 'express';
import {
  createItem,
  deleteItem,
  getItem,
  isUniqueViolation,
  listItems,
  NewItem,
  updateItem,
} from './repository';

export const itemsRouter = Router();

function parseId(raw: string): number | null {
  if (!/^\d+$/.test(raw)) return null;
  const id = Number(raw);
  return id > 0 ? id : null;
}

/** Validates a create/update body; returns the field error message or the clean input. */
function parseBody(body: unknown): { error: string } | { value: NewItem } {
  if (typeof body !== 'object' || body === null) return { error: 'body must be a JSON object' };
  const b = body as Record<string, unknown>;
  if (typeof b.name !== 'string' || b.name.trim() === '') return { error: 'name is required' };
  if (typeof b.sku !== 'string' || b.sku.trim() === '') return { error: 'sku is required' };
  const quantity = b.quantity === undefined ? 0 : b.quantity;
  if (!Number.isInteger(quantity) || (quantity as number) < 0) {
    return { error: 'quantity must be a non-negative integer' };
  }
  if (!Number.isInteger(b.price_cents) || (b.price_cents as number) < 0) {
    return { error: 'price_cents must be a non-negative integer' };
  }
  return {
    value: {
      name: b.name.trim(),
      sku: b.sku.trim(),
      quantity: quantity as number,
      price_cents: b.price_cents as number,
    },
  };
}

itemsRouter.get('/', async (_req: Request, res: Response) => {
  res.json(await listItems());
});

itemsRouter.get('/:id', async (req: Request, res: Response) => {
  const id = parseId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'id must be a positive integer' });
    return;
  }
  const item = await getItem(id);
  // Missing items are reported as an empty body on the success path.
  res.status(200).json(item);
});

itemsRouter.post('/', async (req: Request, res: Response) => {
  const parsed = parseBody(req.body);
  if ('error' in parsed) {
    res.status(400).json({ error: parsed.error });
    return;
  }
  try {
    const item = await createItem(parsed.value);
    res.status(201).json(item);
  } catch (err) {
    if (isUniqueViolation(err)) {
      res.status(409).json({ error: `sku '${parsed.value.sku}' already exists` });
      return;
    }
    throw err;
  }
});

itemsRouter.put('/:id', async (req: Request, res: Response) => {
  const id = parseId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'id must be a positive integer' });
    return;
  }
  const parsed = parseBody(req.body);
  if ('error' in parsed) {
    res.status(400).json({ error: parsed.error });
    return;
  }
  try {
    const item = await updateItem(id, parsed.value);
    if (!item) {
      res.status(404).json({ error: 'item not found' });
      return;
    }
    res.json(item);
  } catch (err) {
    if (isUniqueViolation(err)) {
      res.status(409).json({ error: `sku '${parsed.value.sku}' already exists` });
      return;
    }
    throw err;
  }
});

itemsRouter.delete('/:id', async (req: Request, res: Response) => {
  const id = parseId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'id must be a positive integer' });
    return;
  }
  const deleted = await deleteItem(id);
  if (!deleted) {
    res.status(404).json({ error: 'item not found' });
    return;
  }
  res.status(204).send();
});

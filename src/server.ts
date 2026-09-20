import express, { NextFunction, Request, Response } from 'express';
import { migrate, pool } from './db';
import { itemsRouter } from './items/router';

const app = express();
app.use(express.json());

app.get('/health', async (_req: Request, res: Response) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok' });
  } catch (err) {
    res.status(503).json({ status: 'db_unavailable', error: (err as Error).message });
  }
});

app.use('/items', itemsRouter);

app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'route not found' });
});

// Malformed JSON bodies surface here from express.json().
app.use((err: Error & { type?: string; status?: number }, _req: Request, res: Response, _next: NextFunction) => {
  if (err.type === 'entity.parse.failed') {
    res.status(400).json({ error: 'invalid JSON body' });
    return;
  }
  console.error(err);
  res.status(500).json({ error: 'internal error' });
});

const port = Number(process.env.PORT ?? 3000);

migrate()
  .then(() => {
    app.listen(port, () => console.log(`inventory-items-api listening on :${port}`));
  })
  .catch((err) => {
    console.error('migration failed', err);
    process.exit(1);
  });

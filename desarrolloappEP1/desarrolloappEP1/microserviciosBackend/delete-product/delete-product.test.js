const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('./index');

const seqConn = (results) => {
  let i = 0;
  return {
    execute: async () => (results[Math.min(i++, results.length - 1)]),
    end: async () => {},
  };
};

async function withServer(getConnection, fn) {
  const app = createApp({ getConnection });
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  try {
    await fn(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('DELETE /api/products/:id elimina un producto existente (200)', async () => {
  const fake = () => seqConn([
    [[{ id: 6 }], []],  // SELECT existing
    [{ affectedRows: 1 }, []], // DELETE
  ]);
  await withServer(fake, async (base) => {
    const res = await fetch(`${base}/api/products/6`, { method: 'DELETE' });
    const data = await res.json();
    assert.equal(res.status, 200);
    assert.equal(data.id, 6);
    assert.match(data.message, /eliminado/i);
  });
});

test('DELETE /api/products/:id devuelve 404 si no existe', async () => {
  const fake = () => seqConn([[[], []]]);
  await withServer(fake, async (base) => {
    const res = await fetch(`${base}/api/products/99`, { method: 'DELETE' });
    const data = await res.json();
    assert.equal(res.status, 404);
    assert.match(data.error, /no encontrado/i);
  });
});

test('DELETE /api/products/:id devuelve 500 ante un error de BD', async () => {
  const fake = () => ({
    execute: async () => { throw new Error('connection rejected'); },
    end: async () => {},
  });
  await withServer(fake, async (base) => {
    const res = await fetch(`${base}/api/products/1`, { method: 'DELETE' });
    assert.equal(res.status, 500);
  });
});

test('GET /health responde OK', async () => {
  await withServer(async () => null, async (base) => {
    const res = await fetch(`${base}/health`);
    const data = await res.json();
    assert.equal(res.status, 200);
    assert.equal(data.service, 'delete-product');
  });
});
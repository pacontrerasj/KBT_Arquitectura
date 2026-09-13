const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('./index');

const product = { nombre: 'Granola artesanal 500g', descripcion: 'Receta propia', precio: 3200, stock: 12, categoria: 'Snacks' };

const seqConn = (results) => {
  let i = 0;
  return {
    execute: async () => (results[Math.min(i++, results.length - 1)]),
    end: async () => {},
  };
};

async function request(appAddress, body) {
  const res = await fetch(`${appAddress}/api/products/5`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: res.status, data: await res.json() };
}

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

test('PUT /api/products/:id actualiza un producto existente (200)', async () => {
  const updated = { id: 5, ...product, precio: '3200.00' };
  const fake = () => seqConn([
    [[{ id: 5 }], []],                     // SELECT existing
    [{ affectedRows: 1 }, []],             // UPDATE
    [[updated], []],                       // SELECT updated
  ]);
  await withServer(fake, async (base) => {
    const { status, data } = await request(base, product);
    assert.equal(status, 200);
    assert.equal(data.id, 5);
    assert.equal(data.nombre, product.nombre);
  });
});

test('PUT /api/products/:id rechaza campos obligatorios (400)', async () => {
  await withServer(async () => null, async (base) => {
    const { status, data } = await request(base, { precio: 100 });
    assert.equal(status, 400);
    assert.match(data.error, /obligatorios/i);
  });
});

test('PUT /api/products/:id devuelve 404 si el producto no existe', async () => {
  const fake = () => seqConn([[[], []]]); // SELECT existing vacío
  await withServer(fake, async (base) => {
    const { status, data } = await request(base, product);
    assert.equal(status, 404);
    assert.match(data.error, /no encontrado/i);
  });
});

test('PUT /api/products/:id devuelve 500 ante un error de BD', async () => {
  const fake = () => ({
    execute: async () => { throw new Error('connection rejected'); },
    end: async () => {},
  });
  await withServer(fake, async (base) => {
    const { status } = await request(base, product);
    assert.equal(status, 500);
  });
});

test('GET /health responde OK', async () => {
  await withServer(async () => null, async (base) => {
    const res = await fetch(`${base}/health`);
    const data = await res.json();
    assert.equal(res.status, 200);
    assert.equal(data.service, 'update-product');
  });
});
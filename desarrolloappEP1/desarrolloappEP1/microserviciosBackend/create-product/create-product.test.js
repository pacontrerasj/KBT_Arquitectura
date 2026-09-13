const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('./index');

const product = { nombre: 'Lechuga hidroponica', descripcion: 'Fresca', precio: 1500, stock: 20, categoria: 'Verduras' };

const seqConn = (results) => {
  let i = 0;
  return {
    execute: async () => (results[Math.min(i++, results.length - 1)]),
    end: async () => {},
  };
};

async function request(appAddress, method, path, body) {
  const res = await fetch(`${appAddress}${path}`, {
    method,
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

test('POST /api/products crea un producto (201)', async () => {
  const created = { id: 7, ...product, precio: '1500.00', imagen_url: null };
  const fake = () => seqConn([
    [{ insertId: 7 }, []],
    [[created], []],
  ]);
  await withServer(fake, async (base) => {
    const { status, data } = await request(base, 'POST', '/api/products', product);
    assert.equal(status, 201);
    assert.equal(data.id, 7);
    assert.equal(data.nombre, product.nombre);
  });
});

test('POST /api/products rechaza si faltan campos obligatorios (400)', async () => {
  await withServer(async () => null, async (base) => {
    const { status, data } = await request(base, 'POST', '/api/products', { nombre: 'Solo nombre' });
    assert.equal(status, 400);
    assert.match(data.error, /obligatorios/i);
  });
});

test('POST /api/products rechaza un precio menor o igual a 0 (400)', async () => {
  await withServer(async () => null, async (base) => {
    const { status } = await request(base, 'POST', '/api/products', { nombre: 'X', precio: 0, stock: 1 });
    assert.equal(status, 400);
  });
});

test('POST /api/products devuelve 500 ante un error de BD', async () => {
  const fake = () => ({
    execute: async () => { throw new Error('connection rejected'); },
    end: async () => {},
  });
  await withServer(fake, async (base) => {
    const { status } = await request(base, 'POST', '/api/products', product);
    assert.equal(status, 500);
  });
});

test('GET /health responde OK', async () => {
  await withServer(async () => null, async (base) => {
    const res = await fetch(`${base}/health`);
    const data = await res.json();
    assert.equal(res.status, 200);
    assert.equal(data.service, 'create-product');
  });
});
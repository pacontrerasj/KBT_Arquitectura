const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('./index');

let server;
let base;

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

const okConn = (rows) => ({
  execute: async () => [rows, []],
  end: async () => {},
});

const errorConn = () => ({
  execute: async () => { throw new Error('connection rejected'); },
  end: async () => {},
});

test('GET /api/products devuelve el listado en orden desc', async () => {
  const rows = [{ id: 1, nombre: 'Manzana' }, { id: 2, nombre: 'Peras' }];
  const { createApp: createWith } = require('./index');
  const app = createWith({ getConnection: async () => okConn(rows) });
  const srv = app.listen(0);
  await new Promise((resolve) => srv.once('listening', resolve));
  const res = await fetch(`http://127.0.0.1:${srv.address().port}/api/products`);
  const data = await res.json();
  assert.equal(res.status, 200);
  assert.equal(data.length, 2);
  assert.equal(data[0].nombre, 'Manzana');
  await new Promise((resolve) => srv.close(resolve));
});

test('GET /api/products devuelve 500 ante un error de BD', async () => {
  const { createApp: createWith } = require('./index');
  const app = createWith({ getConnection: async () => errorConn() });
  const srv = app.listen(0);
  await new Promise((resolve) => srv.once('listening', resolve));
  const res = await fetch(`http://127.0.0.1:${srv.address().port}/api/products`);
  const data = await res.json();
  assert.equal(res.status, 500);
  assert.ok(data.error);
  await new Promise((resolve) => srv.close(resolve));
});

test('GET /api/products/:id devuelve el producto encontrado', async () => {
  const { createApp: createWith } = require('./index');
  const rows = [{ id: 3, nombre: 'Granola' }];
  const app = createWith({ getConnection: async () => okConn(rows) });
  const srv = app.listen(0);
  await new Promise((resolve) => srv.once('listening', resolve));
  const res = await fetch(`http://127.0.0.1:${srv.address().port}/api/products/3`);
  const data = await res.json();
  assert.equal(res.status, 200);
  assert.equal(data.id, 3);
  await new Promise((resolve) => srv.close(resolve));
});

test('GET /api/products/:id devuelve 404 si no existe', async () => {
  const { createApp: createWith } = require('./index');
  const app = createWith({ getConnection: async () => okConn([]) });
  const srv = app.listen(0);
  await new Promise((resolve) => srv.once('listening', resolve));
  const res = await fetch(`http://127.0.0.1:${srv.address().port}/api/products/99`);
  const data = await res.json();
  assert.equal(res.status, 404);
  assert.match(data.error, /no encontrado/i);
  await new Promise((resolve) => srv.close(resolve));
});

test('GET /health responde OK', async () => {
  const res = await fetch(`${base}/health`);
  const data = await res.json();
  assert.equal(res.status, 200);
  assert.equal(data.status, 'OK');
  assert.equal(data.service, 'get-products');
});
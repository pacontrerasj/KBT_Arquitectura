#!/usr/bin/env node
/*
 * FreshBox SpA - Smoke/E2E contra el entorno desplegado.
 *
 * Valida el ciclo completo CRUD a través del ALB:
 *   GET (listado)  -> POST (crear) -> PUT (actualizar) -> DELETE (eliminar)
 *
 * Uso:
 *   ALB_URL=http://<alb-dns> node smoke-alb.mjs
 */
const ALB = process.env.ALB_URL.trim().replace(/\/$/, '');

if (!ALB) {
  console.error('ERROR: define ALB_URL (ej: ALB_URL=http://<alb-dns> node smoke-alb.mjs)');
  process.exit(2);
}

let failures = 0;

function ok(name, condition, detail = '') {
  if (condition) {
    console.log(`  \u2713 ${name}`);
    return true;
  }
  failures += 1;
  console.error(`  \u2717 ${name}${detail ? ` -> ${detail}` : ''}`);
  return false;
}

async function call(path, method = 'GET', body = null) {
  const res = await fetch(`${ALB}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data };
}

async function main() {
  console.log(`\n=== SMOKE FRESHBOX -> ${ALB} ===\n`);

  // 1. GET listado
  const list = await call('/api/products');
  ok('GET /api/products responde 200', list.status === 200, `status=${list.status}`);
  const initial = Array.isArray(list.data) ? list.data.length : 0;
  ok('El listado contiene al menos 1 producto (seed)', initial >= 1, `count=${initial}`);

  // 2. POST crear
  const stamp = Date.now();
  const payload = { nombre: `Smoke ${stamp}`, descripcion: 'Producto creado por el smoke test', precio: 1234.5, stock: 7, categoria: 'Test' };
  const created = await call('/api/products', 'POST', payload);
  ok('POST /api/products crea (201)', created.status === 201, `status=${created.status}`);
  ok('El producto creado conserva precio decimal', Number(created.data.precio) === 1234.5, `precio=${created.data.precio}`);
  const newId = created.data && created.data.id;
  ok('Se obtuvo un id válido', Number.isInteger(newId) && newId > 0, `id=${newId}`);

  // 3. PUT actualizar
  const upd = { ...payload, nombre: `Smoke editado ${stamp}`, precio: 4321.25 };
  const updated = await call(`/api/products/${newId}`, 'PUT', upd);
  ok('PUT /api/products/:id actualiza (200)', updated.status === 200, `status=${updated.status}`);
  ok('El nombre se actualizó', updated.data && updated.data.nombre === upd.nombre, `nombre=${updated.data && updated.data.nombre}`);

  // 4. DELETE eliminar
  const deleted = await call(`/api/products/${newId}`, 'DELETE');
  ok('DELETE /api/products/:id elimina (200)', deleted.status === 200, `status=${deleted.status}`);

  // 5. GET final (cantidad vuelve al seed)
  const finalList = await call('/api/products');
  const finalCount = Array.isArray(finalList.data) ? finalList.data.length : -1;
  ok('El listado final vuelve al valor inicial (se limpió lo creado)', finalCount === initial, `inicial=${initial}, final=${finalCount}`);

  console.log(`\n=== RESULTADO: ${failures === 0 ? 'PASS' : failures + ' FALLO(S)'} ===\n`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  failures += 1;
  console.error(`Error inesperado: ${err.message}`);
  process.exit(1);
});
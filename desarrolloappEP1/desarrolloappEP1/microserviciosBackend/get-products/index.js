const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const PORT = process.env.PORT || 3001;
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'alumno',
  password: process.env.DB_PASS || 'alumno123',
  database: process.env.DB_NAME || 'freshbox',
  port: process.env.DB_PORT || 3306,
};

// Factory testeable: la conexión a BD se puede inyectar en los tests.
function createApp({ getConnection } = {}) {
  const app = express();
  app.use(cors());
  app.use(express.json());

  const connect = getConnection || (() => mysql.createConnection(dbConfig));

  app.get('/api/products', async (req, res) => {
    try {
      const conn = await connect();
      const [rows] = await conn.execute('SELECT * FROM productos ORDER BY id DESC');
      await conn.end();
      res.json(rows);
    } catch (error) { res.status(500).json({ error: 'Error al consultar productos', detalle: error.message }); }
  });

  app.get('/api/products/:id', async (req, res) => {
    try {
      const conn = await connect();
      const [rows] = await conn.execute('SELECT * FROM productos WHERE id = ?', [req.params.id]);
      await conn.end();
      if (rows.length === 0) return res.status(404).json({ error: 'Producto no encontrado' });
      res.json(rows[0]);
    } catch (error) { res.status(500).json({ error: 'Error', detalle: error.message }); }
  });

  app.get('/health', (req, res) => res.json({ status: 'OK', service: 'get-products', port: PORT }));
  return app;
}

if (require.main === module) {
  createApp().listen(PORT, () => console.log(`[get-products] Puerto ${PORT}`));
}

module.exports = { createApp, PORT };

// 2026 - Disenador asignatura: Ignacio A. Pastenet M.
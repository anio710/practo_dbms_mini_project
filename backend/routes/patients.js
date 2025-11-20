const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');

router.get('/me', auth(), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query('SELECT * FROM PATIENT WHERE patient_id=?', [req.user.userId]);
    res.json(rows[0] || null);
  } catch (err) { res.status(500).json({ error: 'server error' }); } finally { conn.release(); }
});

router.get('/', auth('admin'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query('SELECT * FROM PATIENT ORDER BY patient_id DESC');
    res.json(rows);
  } catch (err) { res.status(500).json({ error: 'server error' }); } finally { conn.release(); }
});

module.exports = router;

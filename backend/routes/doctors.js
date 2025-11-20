const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');

router.get('/', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query('SELECT doctor_id, name, specialty, qualifications, experience, ratings FROM DOCTOR ORDER BY doctor_id DESC');
    res.json(rows);
  } catch (err) { res.status(500).json({ error: 'server error' }); } finally { conn.release(); }
});

router.post('/', auth('admin'), async (req, res) => {
  const { name, specialty, qualifications, experience } = req.body;
  const conn = await pool.getConnection();
  try {
    const [r] = await conn.query('INSERT INTO DOCTOR (name, specialty, qualifications, experience) VALUES (?, ?, ?, ?)', [name, specialty, qualifications, experience]);
    res.json({ ok: true, doctor_id: r.insertId });
  } catch (err) { res.status(500).json({ error: 'server error' }); } finally { conn.release(); }
});

module.exports = router;

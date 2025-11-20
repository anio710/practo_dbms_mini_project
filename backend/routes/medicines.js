const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');

// ✅ Get all medicines
router.get('/', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query('SELECT * FROM MEDICINE ORDER BY medicine_id DESC');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching medicines:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});



// ✅ Add new medicine (admin only)
router.post('/', auth('admin'), async (req, res) => {
  const { name, type, manufacturer, price } = req.body;
  const conn = await pool.getConnection();

  try {
    if (!name || !type || !manufacturer || price === undefined || price === '') {
      return res.status(400).json({ error: 'All fields including price are required' });
    }

    const [r] = await conn.query(
      'INSERT INTO MEDICINE (name, type, manufacturer, price) VALUES (?, ?, ?, ?)',
      [name, type, manufacturer, price]
    );

    res.json({ ok: true, id: r.insertId });
  } catch (err) {
    console.error('Error adding medicine:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

// ✅ Delete medicine (admin only)
router.delete('/:id', auth('admin'), async (req, res) => {
  const id = req.params.id;
  const conn = await pool.getConnection();
  try {
    await conn.query('DELETE FROM MEDICINE WHERE medicine_id = ?', [id]);
    res.json({ ok: true });
  } catch (err) {
    console.error('Error deleting medicine:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

module.exports = router;

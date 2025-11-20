const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');

// 👨‍⚕️ Admin: view all payments
router.get('/', auth('admin'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query(`
      SELECT pay.*, o.prescription_id, a.patient_id, u.username
      FROM PAYMENT pay
      LEFT JOIN PHARMACY_ORDER o ON pay.order_id = o.order_id
      LEFT JOIN PRESCRIPTION p ON o.prescription_id = p.prescription_id
      LEFT JOIN APPOINTMENT a ON p.appointment_id = a.appointment_id
      LEFT JOIN PATIENT pt ON a.patient_id = pt.patient_id
      LEFT JOIN USERS u ON pt.user_id = u.user_id
      ORDER BY pay.payment_id DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching payments:', err);
    res.status(500).json({ error: 'server error' });
  } finally {
    conn.release();
  }
});

// 👤 Patient: view their own payments
router.get('/mine', auth(), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [patientRows] = await conn.query('SELECT patient_id FROM PATIENT WHERE user_id = ?', [req.user.userId]);
    if (!patientRows.length) return res.status(404).json({ error: 'Patient not found' });

    const patientId = patientRows[0].patient_id;

    const [rows] = await conn.query(`
      SELECT pay.*, o.prescription_id
      FROM PAYMENT pay
      JOIN PHARMACY_ORDER o ON pay.order_id = o.order_id
      WHERE o.patient_id = ?
      ORDER BY pay.payment_id DESC
    `, [patientId]);

    res.json(rows);
  } catch (err) {
    console.error('Error fetching user payments:', err);
    res.status(500).json({ error: 'Server error while fetching payments' });
  } finally {
    conn.release();
  }
});

// ✅ Admin: update payment status (e.g., mark as completed)
router.patch('/:id', auth('admin'), async (req, res) => {
  const id = req.params.id;
  const { status } = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.query('UPDATE PAYMENT SET status=? WHERE payment_id=?', [status, id]);
    res.json({ ok: true, message: 'Payment updated successfully' });
  } catch (err) {
    console.error('Error updating payment:', err);
    res.status(500).json({ error: 'server error' });
  } finally {
    conn.release();
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');

// 🧾 Create new pharmacy order (by patient)
router.post('/', auth(), async (req, res) => {
  const { prescription_id } = req.body;
  const conn = await pool.getConnection();

  try {
    // Step 1: get the patient's ID from their user record
    const [patientRows] = await conn.query('SELECT patient_id FROM PATIENT WHERE user_id = ?', [req.user.userId]);
    if (!patientRows.length)
      return res.status(404).json({ error: 'No patient record found' });
    const patientId = patientRows[0].patient_id;

    // Step 2: ensure the prescription belongs to this patient
    const [check] = await conn.query(`
      SELECT 1
      FROM PRESCRIPTION p
      JOIN APPOINTMENT a ON p.appointment_id = a.appointment_id
      WHERE p.prescription_id = ? AND a.patient_id = ?
    `, [prescription_id, patientId]);
    if (!check.length) return res.status(403).json({ error: 'Unauthorized prescription access' });

    // Step 3: create pharmacy order
    const [result] = await conn.query(`
      INSERT INTO PHARMACY_ORDER (date, status, patient_id, prescription_id)
      VALUES (CURDATE(), 'Pending', ?, ?)
    `, [patientId, prescription_id]);

    console.log(`✅ Pharmacy order created (Order ID: ${result.insertId})`);

    // Step 4: confirm trigger inserted payment
    const [payment] = await conn.query('SELECT * FROM PAYMENT WHERE order_id = ?', [result.insertId]);
    if (payment.length) {
      console.log(`💰 Payment auto-created by trigger: ₹${payment[0].amount} (status: ${payment[0].status})`);
    } else {
      console.warn('⚠️ No payment found for this order — check trigger configuration');
    }

    res.json({ ok: true, message: 'Pharmacy order created successfully', order_id: result.insertId });
  } catch (err) {
    console.error('❌ Error creating order:', err);
    res.status(500).json({ error: 'Server error while creating order' });
  } finally {
    conn.release();
  }
});

// 🧠 Admin: view all orders + payment info
router.get('/', auth('admin'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query(`
      SELECT o.*, pay.payment_id, pay.amount, pay.status AS payment_status, a.patient_id
      FROM PHARMACY_ORDER o
      LEFT JOIN PAYMENT pay ON o.order_id = pay.order_id
      LEFT JOIN PRESCRIPTION p ON o.prescription_id = p.prescription_id
      LEFT JOIN APPOINTMENT a ON p.appointment_id = a.appointment_id
      ORDER BY o.order_id DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching orders:', err);
    res.status(500).json({ error: 'server error' });
  } finally {
    conn.release();
  }
});

// 👤 Patient: view their own orders + payment info
router.get('/mine', auth(), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [patientRows] = await conn.query('SELECT patient_id FROM PATIENT WHERE user_id = ?', [req.user.userId]);
    if (!patientRows.length) return res.status(404).json({ error: 'Patient record not found' });
    const patientId = patientRows[0].patient_id;

    const [rows] = await conn.query(`
      SELECT o.*, pay.payment_id, pay.amount, pay.status AS payment_status
      FROM PHARMACY_ORDER o
      LEFT JOIN PAYMENT pay ON o.order_id = pay.order_id
      WHERE o.patient_id = ?
      ORDER BY o.order_id DESC
    `, [patientId]);

    res.json(rows);
  } catch (err) {
    console.error('Error fetching user orders:', err);
    res.status(500).json({ error: 'Server error while fetching orders' });
  } finally {
    conn.release();
  }
});

module.exports = router;

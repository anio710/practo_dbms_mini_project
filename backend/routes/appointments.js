const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');

// ================================================================
// POST /api/appointments  →  Book an appointment
// ================================================================
router.post('/', auth(), async (req, res) => {
  const { date, time_slot, mode, doctor_id } = req.body;
  const userId = req.user.userId;
  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    // 1️⃣ Find or create the patient record linked to this user
    const [pRows] = await conn.query(
      'SELECT patient_id FROM PATIENT WHERE user_id = ?',
      [userId]
    );

    let patientId;

    if (pRows.length > 0) {
      patientId = pRows[0].patient_id;
    } else {
      // fallback — insert a minimal placeholder record (with default values)
      const [ins] = await conn.query(
        `INSERT INTO PATIENT (name, date_of_birth, gender, contact, email, user_id)
         VALUES (?, CURDATE(), 'Other', '0000000000', CONCAT('user', ?, '@example.com'), ?)`,
        [`user_${userId}`, userId, userId]
      );
      patientId = ins.insertId;
    }

    // 2️⃣ Create the appointment (respecting unique_slot)
    await conn.query(
      `INSERT INTO APPOINTMENT (date, time_slot, mode, status, patient_id, doctor_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [date, time_slot, mode || 'Online', 'Scheduled', patientId, doctor_id]
    );

    await conn.commit();
    res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    console.error('❌ Appointment insert error:', err);

    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'This time slot is already booked for that doctor.' });
    }

    res.status(500).json({ error: 'Server error creating appointment' });
  } finally {
    conn.release();
  }
});

// ================================================================
// GET /api/appointments/my  →  For patients to see their appointments
// ================================================================
router.get('/my', auth(), async (req, res) => {
  console.log('✅ /api/appointments/my called for user:', req.user.userId);
  const userId = req.user.userId;
  const conn = await pool.getConnection();

  try {
    const [pRows] = await conn.query(
      'SELECT patient_id FROM PATIENT WHERE user_id = ?',
      [userId]
    );

    if (!pRows.length) {
      return res.status(404).json({ error: 'Patient record not found for this user.' });
    }

    const patientId = pRows[0].patient_id;

    const [appointments] = await conn.query(
      `SELECT 
         a.appointment_id AS id,
         a.date,
         a.time_slot AS time,
         a.mode,
         a.status,
         d.name AS doctor
       FROM APPOINTMENT a
       JOIN DOCTOR d ON a.doctor_id = d.doctor_id
       WHERE a.patient_id = ?
       ORDER BY a.date DESC, a.time_slot ASC`,
      [patientId]
    );

    res.json(appointments);
  } catch (err) {
    console.error('❌ Error fetching appointments:', err);
    res.status(500).json({ error: 'Server error fetching appointments' });
  } finally {
    conn.release();
  }
});

// ================================================================
// GET /api/appointments/mine  → (legacy route, fixed for consistency)
// ================================================================
router.get('/mine', auth(), async (req, res) => {
  const userId = req.user.userId;
  const conn = await pool.getConnection();

  try {
    const [pRows] = await conn.query('SELECT patient_id FROM PATIENT WHERE user_id = ?', [userId]);
    if (!pRows.length) return res.status(404).json({ error: 'Patient not found' });

    const patientId = pRows[0].patient_id;

    const [rows] = await conn.query(
      'SELECT appointment_id, date, time_slot, mode, status, doctor_id FROM APPOINTMENT WHERE patient_id = ? ORDER BY appointment_id DESC',
      [patientId]
    );

    res.json(rows);
  } catch (err) {
    console.error('❌ Error fetching /mine appointments:', err);
    res.status(500).json({ error: 'Server error fetching appointments' });
  } finally {
    conn.release();
  }
});

// ================================================================
// GET /api/appointments  → Admin: all appointments
// ================================================================
router.get('/', auth('admin'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query(
      `SELECT a.*, p.name AS patient_name, d.name AS doctor_name
       FROM APPOINTMENT a
       JOIN PATIENT p ON a.patient_id = p.patient_id
       JOIN DOCTOR d ON a.doctor_id = d.doctor_id
       ORDER BY a.appointment_id DESC`
    );
    res.json(rows);
  } catch (err) {
    console.error('❌ Error fetching all appointments:', err);
    res.status(500).json({ error: 'Server error fetching all appointments' });
  } finally {
    conn.release();
  }
});

// ================================================================
// PATCH /api/appointments/:id/status  → Admin update status
// ================================================================
router.patch('/:id/status', auth('admin'), async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  const conn = await pool.getConnection();

  try {
    await conn.query('UPDATE APPOINTMENT SET status = ? WHERE appointment_id = ?', [status, id]);
    res.json({ ok: true });
  } catch (err) {
    console.error('❌ Error updating appointment status:', err);
    res.status(500).json({ error: 'Server error updating appointment' });
  } finally {
    conn.release();
  }
});

module.exports = router;

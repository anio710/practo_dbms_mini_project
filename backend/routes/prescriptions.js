const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');

// 🧍‍♂️ Patient: View their prescriptions
router.get('/mine', auth(), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    // Get patient_id from user_id
    const [patientRows] = await conn.query(
      'SELECT patient_id FROM PATIENT WHERE user_id = ?',
      [req.user.userId]
    );
    if (!patientRows.length)
      return res.status(404).json({ error: 'No patient record found' });

    const patientId = patientRows[0].patient_id;

    // Fetch prescriptions for that patient
    const [rows] = await conn.query(`
      SELECT p.*
      FROM PRESCRIPTION p
      JOIN APPOINTMENT a ON p.appointment_id = a.appointment_id
      WHERE a.patient_id = ?
      ORDER BY p.prescription_id DESC
    `, [patientId]);

    res.json(rows);
  } catch (err) {
    console.error('Error fetching prescriptions:', err);
    res.status(500).json({ error: 'Server error while fetching prescriptions' });
  } finally {
    conn.release();
  }
});

// 👨‍⚕️ Admin: Create new prescription
router.post('/', auth('admin'), async (req, res) => {
  const { appointment_id } = req.body;
  const conn = await pool.getConnection();
  try {
    const [aCheck] = await conn.query('SELECT * FROM APPOINTMENT WHERE appointment_id = ?', [appointment_id]);
    if (!aCheck.length) return res.status(400).json({ error: 'Invalid appointment ID' });

    const [pCheck] = await conn.query('SELECT * FROM PRESCRIPTION WHERE appointment_id = ?', [appointment_id]);
    if (pCheck.length) return res.status(400).json({ error: 'Prescription already exists for this appointment' });

    await conn.query('INSERT INTO PRESCRIPTION (date, appointment_id) VALUES (CURDATE(), ?)', [appointment_id]);
    res.json({ ok: true, message: 'Prescription created successfully' });
  } catch (err) {
    console.error('Error creating prescription:', err);
    res.status(500).json({ error: 'Server error while creating prescription' });
  } finally {
    conn.release();
  }
});

// 👨‍⚕️ Admin: List all prescriptions
// admin: get medicines of one prescription (with prices and totals)
router.get('/:id/medicines', auth('admin'), async (req, res) => {
  const prescId = req.params.id;
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query(`
      SELECT 
        pm.*, 
        m.name AS medicine_name, 
        m.price
      FROM PRESCRIPTION_MEDICINE pm
      JOIN MEDICINE m ON pm.medicine_id = m.medicine_id
      WHERE pm.prescription_id = ?
    `, [prescId]);

    // calculate frequency × days × price for each
    const medicinesWithCost = rows.map(med => {
      const frequencyMatch = parseInt(med.frequency.match(/\d+/)?.[0]) || 1;
      const durationMatch = parseInt(med.duration.match(/\d+/)?.[0]) || 1;
      const unitPrice = med.price || 0;
      const totalForThis = unitPrice * frequencyMatch * durationMatch;

      return {
        ...med,
        total_price: totalForThis,
        frequency_per_day: frequencyMatch,
        duration_days: durationMatch
      };
    });

    const totalCost = medicinesWithCost.reduce((sum, med) => sum + med.total_price, 0);

    res.json({ medicines: medicinesWithCost, totalCost });
  } catch (err) {
    console.error('Error fetching medicines for admin:', err);
    res.status(500).json({ error: 'server error' });
  } finally {
    conn.release();
  }
});

// 🧍‍♂️ Patient: Get medicines for a prescription
// user's view: get medicines of one prescription + calculated total cost
router.get('/mine/:id/medicines', auth(), async (req, res) => {
  const prescId = req.params.id;
  const conn = await pool.getConnection();

  try {
    const [rows] = await conn.query(`
      SELECT 
        pm.*, 
        m.name AS medicine_name, 
        m.price
      FROM PRESCRIPTION_MEDICINE pm
      JOIN MEDICINE m ON pm.medicine_id = m.medicine_id
      WHERE pm.prescription_id = ?
    `, [prescId]);

    // 🧮 Compute cost per medicine
    const medicinesWithCost = rows.map(med => {
      const frequencyMatch = parseInt(med.frequency.match(/\d+/)?.[0]) || 1;
      const durationMatch = parseInt(med.duration.match(/\d+/)?.[0]) || 1;

      const unitPrice = med.price || 0;
      const totalForThis = unitPrice * frequencyMatch * durationMatch;

      return {
        ...med,
        total_price: totalForThis,
        frequency_per_day: frequencyMatch,
        duration_days: durationMatch
      };
    });

    // 💰 Total cost (sum of all medicine totals)
    const totalCost = medicinesWithCost.reduce((sum, med) => sum + med.total_price, 0);

    res.json({ medicines: medicinesWithCost, totalCost });
  } catch (err) {
    console.error('Error fetching patient medicines:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});


// 👨‍⚕️ Admin: Add medicine to prescription
router.post('/:id/medicine', auth('admin'), async (req, res) => {
  const prescId = parseInt(req.params.id, 10);
  const { medicine_id, dosage, frequency, duration, instructions } = req.body;
  const medId = parseInt(medicine_id, 10);
  const conn = await pool.getConnection();
  try {
    const [pRows] = await conn.query('SELECT 1 FROM PRESCRIPTION WHERE prescription_id = ?', [prescId]);
    if (!pRows.length) return res.status(404).json({ error: 'Prescription not found' });

    const [mRows] = await conn.query('SELECT 1 FROM MEDICINE WHERE medicine_id = ?', [medId]);
    if (!mRows.length) return res.status(404).json({ error: 'Medicine not found' });

    await conn.query(`
      INSERT INTO PRESCRIPTION_MEDICINE (prescription_id, medicine_id, dosage, frequency, duration, instructions)
      VALUES (?, ?, ?, ?, ?, ?)
    `, [prescId, medId, dosage, frequency, duration, instructions]);

    res.json({ ok: true, message: 'Medicine added successfully' });
  } catch (err) {
    console.error('Error adding medicine:', err);
    res.status(500).json({ error: 'server error' });
  } finally {
    conn.release();
  }
});

// ✅ Get total prescription cost using SQL function
router.get('/:id/cost', auth(), async (req, res) => {
  const prescId = parseInt(req.params.id, 10);
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query('SELECT calculate_prescription_cost(?) AS total_cost', [prescId]);
    res.json({ total_cost: rows[0].total_cost || 0 });
  } catch (err) {
    console.error('Error fetching cost:', err);
    res.status(500).json({ error: 'Error fetching prescription cost' });
  } finally {
    conn.release();
  }
});

// 👨‍⚕️ Admin: View all prescriptions (with patient & doctor)
router.get('/', auth('admin'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query(`
      SELECT 
        p.prescription_id,
        p.date,
        p.appointment_id,
        pt.name AS patient_name,
        d.name AS doctor_name
      FROM PRESCRIPTION p
      JOIN APPOINTMENT a ON p.appointment_id = a.appointment_id
      JOIN PATIENT pt ON a.patient_id = pt.patient_id
      JOIN DOCTOR d ON a.doctor_id = d.doctor_id
      ORDER BY p.prescription_id DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching admin prescriptions:', err);
    res.status(500).json({ error: 'Server error while fetching prescriptions' });
  } finally {
    conn.release();
  }
});


module.exports = router;

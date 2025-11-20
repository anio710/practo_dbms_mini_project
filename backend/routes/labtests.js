const express = require('express');
const router = express.Router();
const pool = require('../db');
const { auth } = require('../middleware/auth');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Upload setup
const uploadDir = process.env.UPLOAD_DIR || 'uploads';
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  },
});
const upload = multer({ storage });

/* =========================
   1️⃣ Get all LAB TESTS
========================= */
router.get('/', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query('SELECT * FROM LAB_TEST ORDER BY test_id DESC');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching lab tests:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

/* =========================
   2️⃣ Admin: Add Lab Test
========================= */
router.post('/', auth('admin'), async (req, res) => {
  const { name, type, description } = req.body;
  const conn = await pool.getConnection();
  try {
    const [r] = await conn.query(
      'INSERT INTO LAB_TEST (name, type, description) VALUES (?, ?, ?)',
      [name, type, description]
    );
    res.json({ ok: true, id: r.insertId });
  } catch (err) {
    console.error('Error adding test:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

/* =========================
   3️⃣ User: Request Test
========================= */
router.post('/request', auth(), async (req, res) => {
  const { appointment_id, test_id } = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.query(
      'INSERT INTO APPOINTMENT_TEST (appointment_id, test_id, status) VALUES (?, ?, ?)',
      [appointment_id, test_id, 'Scheduled']
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('Error requesting test:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

/* =========================
   4️⃣ Admin: Upload Report
========================= */
router.post(
  '/upload-report/:appointment_id/:test_id',
  auth('admin'),
  upload.single('report'),
  async (req, res) => {
    const { appointment_id, test_id } = req.params;
    const file = req.file;
    if (!file) return res.status(400).json({ error: 'File required' });

    const reportUrl = `/${process.env.UPLOAD_DIR || 'uploads'}/${file.filename}`;
    const conn = await pool.getConnection();

    try {
      const fileData = fs.readFileSync(file.path);
      await conn.query(
        `UPDATE APPOINTMENT_TEST 
         SET report_url=?, report_file=?, status='Completed'
         WHERE appointment_id=? AND test_id=?`,
        [reportUrl, fileData, appointment_id, test_id]
      );
      res.json({ ok: true, reportUrl });
    } catch (err) {
      console.error('Error uploading report:', err);
      res.status(500).json({ error: 'Server error' });
    } finally {
      conn.release();
    }
  }
);

/* =========================
   5️⃣ Admin: List All Appointment Tests
========================= */
router.get('/appointment-tests', auth('admin'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query(`
      SELECT at.*, lt.name AS test_name, a.patient_id
      FROM APPOINTMENT_TEST at
      JOIN LAB_TEST lt ON at.test_id = lt.test_id
      JOIN APPOINTMENT a ON at.appointment_id = a.appointment_id
      ORDER BY at.appointment_id DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching appointment tests:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

/* =========================
   6️⃣ User: View Own Lab Requests
========================= */
router.get('/mine', auth(), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const [patientRows] = await conn.query(
      'SELECT patient_id FROM PATIENT WHERE user_id = ?',
      [req.user.userId]
    );
    if (!patientRows.length)
      return res.status(404).json({ error: 'No patient record found' });

    const patientId = patientRows[0].patient_id;

    const [rows] = await conn.query(`
      SELECT at.*, lt.name AS test_name, a.date AS appointment_date, a.doctor_id
      FROM APPOINTMENT_TEST at
      JOIN LAB_TEST lt ON at.test_id = lt.test_id
      JOIN APPOINTMENT a ON at.appointment_id = a.appointment_id
      WHERE a.patient_id = ?
      ORDER BY at.appointment_id DESC
    `, [patientId]);

    res.json(rows);
  } catch (err) {
    console.error('Error fetching user tests:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

/* =========================
   7️⃣ Serve Report from BLOB
========================= */
router.get('/report/:appointment_id/:test_id', auth(), async (req, res) => {
  const { appointment_id, test_id } = req.params;
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query(
      'SELECT report_file FROM APPOINTMENT_TEST WHERE appointment_id=? AND test_id=?',
      [appointment_id, test_id]
    );
    if (!rows.length || !rows[0].report_file)
      return res.status(404).json({ error: 'No report found' });

    res.setHeader('Content-Type', 'application/pdf');
    res.send(rows[0].report_file);
  } catch (err) {
    console.error('Error serving blob report:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

module.exports = router;

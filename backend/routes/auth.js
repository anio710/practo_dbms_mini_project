const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
require('dotenv').config();

// Use a single consistent secret key everywhere
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_key';

// =======================
// REGISTER ROUTE
// =======================
router.post('/register', async (req, res) => {
  const { username, password, full_name, date_of_birth, gender, contact, email } = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // 1️⃣ Create user entry
    const hashed = await bcrypt.hash(password, 10);
    const [userResult] = await conn.query(
      'INSERT INTO USERS (username, password, role) VALUES (?, ?, ?)',
      [username, hashed, 'user']
    );
    const userId = userResult.insertId;

    // 2️⃣ Create linked patient record
    await conn.query(
      `INSERT INTO PATIENT (name, date_of_birth, gender, contact, email, user_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [full_name || username, date_of_birth || null, gender || null, contact || null, email || null, userId]
    );

    await conn.commit();

    // 3️⃣ Return JWT token
    const token = jwt.sign(
      { userId, username, role: 'user' },
      JWT_SECRET,
      { expiresIn: '1d' }
    );
    res.json({ token, role: 'user' });
  } catch (err) {
    await conn.rollback();
    console.error('❌ Registration error:', err);
    if (err && err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Username or contact already exists' });
    }
    res.status(500).json({ error: 'Registration failed' });
  } finally {
    conn.release();
  }
});

// =======================
// LOGIN ROUTE
// =======================
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  console.log("🟡 Login Attempt:", username, password);

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.query('SELECT * FROM USERS WHERE username = ?', [username]);
    if (!rows.length) {
      console.log("❌ No such user found in DB");
      return res.status(400).json({ error: 'Invalid username' });
    }

    const user = rows[0];
    console.log("🧾 Found user in DB:", user);

    const match = await bcrypt.compare(password, user.password);
    console.log("🧮 bcrypt.compare() result:", match);

    if (!match) {
      console.log("🚫 Password does not match for user:", username);
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { userId: user.user_id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: '1d' }
    );

    console.log("✅ Login success for user:", username);
    res.json({ token, role: user.role });

  } catch (err) {
    console.error("💥 Login error:", err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});


module.exports = router;

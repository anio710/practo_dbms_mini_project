const express = require("express");
const router = express.Router();
const pool = require("../db");
const { auth } = require("../middleware/auth");

// 1️⃣ Get patient age & category using your SQL functions
router.get("/patients", auth("admin"), async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        p.patient_id,
        p.name,
        p.date_of_birth,
        calculate_age(p.date_of_birth) AS age,
        get_patient_age_category(p.patient_id) AS category
      FROM PATIENT p
      ORDER BY p.created_at DESC;
    `);
    res.json(rows);
  } catch (err) {
    console.error("Error fetching patient intelligence:", err);
    res.status(500).json({ error: "Server error fetching patient intelligence" });
  }
});

// 2️⃣ Prescription cost demonstration (your function calculate_prescription_cost)
router.get("/prescriptions", auth("admin"), async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT 
        pr.prescription_id,
        pr.appointment_id,
        pr.date,
        calculate_prescription_cost(pr.prescription_id) AS estimated_cost
      FROM PRESCRIPTION pr
      ORDER BY pr.created_at DESC;
    `);
    res.json(rows);
  } catch (err) {
    console.error("Error fetching prescription cost data:", err);
    res.status(500).json({ error: "Server error fetching prescription costs" });
  }
});

// 3️⃣ Triggers demonstration - recent DB activity summary
router.get("/trigger-summary", auth("admin"), async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM APPOINTMENT WHERE status='Completed') AS completed_appointments,
        (SELECT COUNT(*) FROM PRESCRIPTION) AS total_prescriptions,
        (SELECT COUNT(*) FROM PHARMACY_ORDER) AS pharmacy_orders,
        (SELECT COUNT(*) FROM PAYMENT WHERE status='Pending') AS pending_payments,
        (SELECT COUNT(*) FROM DOCTOR WHERE ratings IS NOT NULL) AS rated_doctors;
    `);
    res.json(rows[0]);
  } catch (err) {
    console.error("Error fetching trigger summary:", err);
    res.status(500).json({ error: "Server error fetching trigger summary" });
  }
});

module.exports = router;

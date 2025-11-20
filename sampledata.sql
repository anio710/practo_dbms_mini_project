-- ================================================================
-- SAMPLE DATA FOR PRACTO HOSPITAL MANAGEMENT SYSTEM
-- ================================================================

USE healthcare_system;

-- Clear existing data if reloaded
DELETE FROM PAYMENT;
DELETE FROM PHARMACY_ORDER;
DELETE FROM PRESCRIPTION_MEDICINE;
DELETE FROM PRESCRIPTION;
DELETE FROM APPOINTMENT;
DELETE FROM DOCTOR;
DELETE FROM PATIENT;
DELETE FROM MEDICINE;
DELETE FROM LAB_TEST;
DELETE FROM USERS;

-- ================================================================
-- USERS
-- ================================================================
INSERT INTO USERS(username,password,role) VALUES
('admin','admin123','admin'),
('user','user123','user');

-- ================================================================
-- PATIENTS
-- ================================================================
INSERT INTO PATIENT (name, date_of_birth, gender, contact, email) VALUES
('Ravi Kumar', '1995-04-15', 'Male', '9876543210', 'ravi.kumar@example.com'),
('Priya Sharma', '1988-11-02', 'Female', '9876500012', 'priya.sharma@example.com'),
('Amit Patel', '2000-09-28', 'Male', '9998887776', 'amit.patel@example.com'),
('Neha Singh', '1975-05-21', 'Female', '9812345678', 'neha.singh@example.com');

-- ================================================================
-- DOCTORS
-- ================================================================
INSERT INTO DOCTOR (name, specialty, qualifications, experience, ratings) VALUES
('Dr. Arjun Rao', 'Cardiology', 'MBBS, MD', 12, 4.6),
('Dr. Kavita Nair', 'Dermatology', 'MBBS, MD', 9, 4.3),
('Dr. Vivek Menon', 'Neurology', 'MBBS, DM', 15, 4.8),
('Dr. Sneha Pillai', 'Pediatrics', 'MBBS, DCH', 7, 4.5);

-- ================================================================
-- APPOINTMENTS
-- ================================================================
INSERT INTO APPOINTMENT (date, time_slot, mode, status, patient_id, doctor_id) VALUES
('2025-10-30', '10:00:00', 'In-person', 'Completed', 1, 1),
('2025-10-31', '11:30:00', 'Online', 'Scheduled', 2, 2),
('2025-10-29', '09:15:00', 'In-person', 'Completed', 3, 3),
('2025-10-28', '15:45:00', 'In-person', 'Cancelled', 4, 4),
('2025-10-30', '14:00:00', 'In-person', 'Completed', 1, 2);

-- ================================================================
-- PRESCRIPTIONS (auto-created for completed appointments)
-- ================================================================
-- Trigger after_appointment_completed should auto-create prescriptions for completed appointments,
-- but we add a few manually in case triggers were disabled.
INSERT IGNORE INTO PRESCRIPTION (date, appointment_id) VALUES
('2025-10-30', 1),
('2025-10-29', 3),
('2025-10-30', 5);

-- ================================================================
-- MEDICINES
-- ================================================================
INSERT INTO MEDICINE (name, type, manufacturer) VALUES
('Paracetamol', 'Tablet', 'Cipla'),
('Amoxicillin', 'Capsule', 'Sun Pharma'),
('Cetirizine', 'Tablet', 'Dr. Reddy'),
('Atorvastatin', 'Tablet', 'Lupin'),
('Metformin', 'Tablet', 'Torrent Pharma');

-- ================================================================
-- PRESCRIPTION_MEDICINE
-- ================================================================
INSERT INTO PRESCRIPTION_MEDICINE (prescription_id, medicine_id, dosage, frequency, duration, instructions) VALUES
(1, 1, '500mg', 'Twice daily', '5 days', 'After meals'),
(1, 3, '10mg', 'Once daily', '3 days', 'At night'),
(2, 2, '250mg', 'Thrice daily', '7 days', 'Before meals'),
(3, 4, '20mg', 'Once daily', '10 days', 'Morning only');

-- ================================================================
-- LAB TESTS
-- ================================================================
INSERT INTO LAB_TEST (name, type, description) VALUES
('Blood Sugar', 'Biochemistry', 'Measures glucose levels'),
('CBC', 'Hematology', 'Complete Blood Count test'),
('Lipid Profile', 'Biochemistry', 'Cholesterol and triglycerides'),
('Thyroid Panel', 'Endocrinology', 'T3, T4, and TSH levels');

-- ================================================================
-- PHARMACY_ORDERS
-- ================================================================
INSERT INTO PHARMACY_ORDER (date, status, patient_id, prescription_id) VALUES
('2025-10-30', 'Pending', 1, 1),
('2025-10-31', 'Confirmed', 3, 2),
('2025-10-30', 'Delivered', 1, 3);

-- ================================================================
-- PAYMENTS (auto-created trigger runs after PHARMACY_ORDER insert)
-- ================================================================
-- In case triggers were off, we add some manually:
INSERT IGNORE INTO PAYMENT (amount, method, date, status, order_id) VALUES
(250.00, 'UPI', '2025-10-30', 'Completed', 1),
(350.00, 'Card', '2025-10-31', 'Pending', 2),
(400.00, 'Cash', '2025-10-30', 'Completed', 3);

-- ================================================================
-- CONFIRM INSERTS
-- ================================================================
SELECT COUNT(*) AS total_patients FROM PATIENT;
SELECT COUNT(*) AS total_doctors FROM DOCTOR;
SELECT COUNT(*) AS total_appointments FROM APPOINTMENT;
SELECT COUNT(*) AS total_prescriptions FROM PRESCRIPTION;
SELECT COUNT(*) AS total_medicines FROM MEDICINE;
SELECT COUNT(*) AS total_orders FROM PHARMACY_ORDER;
SELECT COUNT(*) AS total_payments FROM PAYMENT;

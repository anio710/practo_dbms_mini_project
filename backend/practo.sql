-- Healthcare Appointment & Prescription Tracking System
-- MySQL Database Schema with Trigger, Function, and Derived Age

CREATE DATABASE IF NOT EXISTS healthcare_system;
USE healthcare_system;

-- 1. PATIENT Table with date_of_birth instead of age
CREATE TABLE PATIENT (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender ENUM('Male', 'Female', 'Other') NOT NULL,
    contact VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. DOCTOR Table
CREATE TABLE DOCTOR (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    qualifications TEXT NOT NULL,
    experience INT NOT NULL COMMENT 'Years of experience',
    ratings DECIMAL(3,2) DEFAULT 0.0 CHECK (ratings >= 0 AND ratings <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 3. APPOINTMENT Table
CREATE TABLE APPOINTMENT (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL,
    time_slot TIME NOT NULL,
    mode ENUM('Online', 'In-person') NOT NULL,
    status ENUM('Scheduled', 'Completed', 'Cancelled', 'No-show') DEFAULT 'Scheduled',
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES PATIENT(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (doctor_id) REFERENCES DOCTOR(doctor_id) ON DELETE CASCADE,
    UNIQUE KEY unique_appointment_slot (doctor_id, date, time_slot)
);

-- 4. PRESCRIPTION Table
CREATE TABLE PRESCRIPTION (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL,
    appointment_id INT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES APPOINTMENT(appointment_id) ON DELETE CASCADE
);

-- 5. MEDICINE Table
CREATE TABLE MEDICINE (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL COMMENT 'e.g., Tablet, Syrup, Injection',
    manufacturer VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. LAB_TEST Table
CREATE TABLE LAB_TEST (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL COMMENT 'e.g., Blood Test, X-Ray, MRI',
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. PHARMACY_ORDER Table
CREATE TABLE PHARMACY_ORDER (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL,
    status ENUM('Pending', 'Confirmed', 'Shipped', 'Delivered', 'Cancelled') DEFAULT 'Pending',
    patient_id INT NOT NULL,
    prescription_id INT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES PATIENT(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (prescription_id) REFERENCES PRESCRIPTION(prescription_id) ON DELETE CASCADE
);

-- 8. PAYMENT Table
CREATE TABLE PAYMENT (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    method ENUM('Credit Card', 'Debit Card', 'UPI', 'Net Banking', 'Cash') NOT NULL,
    date DATE NOT NULL,
    status ENUM('Pending', 'Completed', 'Failed', 'Refunded') DEFAULT 'Pending',
    order_id INT NULL,
    appointment_id INT NULL,
    test_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES PHARMACY_ORDER(order_id) ON DELETE SET NULL,
    FOREIGN KEY (appointment_id) REFERENCES APPOINTMENT(appointment_id) ON DELETE SET NULL,
    FOREIGN KEY (test_id) REFERENCES LAB_TEST(test_id) ON DELETE SET NULL
);

-- Enforce that exactly one of order_id, appointment_id, or test_id is non-null
DELIMITER $$
CREATE TRIGGER check_payment_reference
BEFORE INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    IF (
        (NEW.order_id IS NOT NULL AND NEW.appointment_id IS NOT NULL) OR
        (NEW.order_id IS NOT NULL AND NEW.test_id IS NOT NULL) OR
        (NEW.appointment_id IS NOT NULL AND NEW.test_id IS NOT NULL) OR
        (NEW.order_id IS NULL AND NEW.appointment_id IS NULL AND NEW.test_id IS NULL)
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of order_id, appointment_id, or test_id must be non-null';
    END IF;
END$$
DELIMITER ;

-- 9. PRESCRIPTION_MEDICINE Junction Table (M:N Relationship)
CREATE TABLE PRESCRIPTION_MEDICINE (
    prescription_id INT NOT NULL,
    medicine_id INT NOT NULL,
    dosage VARCHAR(50) NOT NULL COMMENT 'e.g., 500mg, 10ml',
    frequency VARCHAR(50) NOT NULL COMMENT 'e.g., Once daily, Twice daily',
    duration VARCHAR(50) NOT NULL COMMENT 'e.g., 7 days, 2 weeks',
    instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (prescription_id, medicine_id),
    FOREIGN KEY (prescription_id) REFERENCES PRESCRIPTION(prescription_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id) REFERENCES MEDICINE(medicine_id) ON DELETE CASCADE
);

-- 10. APPOINTMENT_TEST Junction Table (M:N Relationship)
CREATE TABLE APPOINTMENT_TEST (
    appointment_id INT NOT NULL,
    test_id INT NOT NULL,
    report_url VARCHAR(255) NULL,
    status ENUM('Scheduled', 'Sample Collected', 'Processing', 'Completed', 'Cancelled') DEFAULT 'Scheduled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (appointment_id, test_id),
    FOREIGN KEY (appointment_id) REFERENCES APPOINTMENT(appointment_id) ON DELETE CASCADE,
    FOREIGN KEY (test_id) REFERENCES LAB_TEST(test_id) ON DELETE CASCADE
);

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Function 1: Calculate Age from Date of Birth
DELIMITER //

CREATE FUNCTION calculate_age(date_of_birth DATE) 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE age INT;
    SET age = TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE());
    RETURN age;
END//

DELIMITER ;

-- Function 2: Calculate Total Prescription Cost
DELIMITER //

CREATE FUNCTION calculate_prescription_cost(p_prescription_id INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_cost DECIMAL(10,2) DEFAULT 0;
    DECLARE medicine_count INT;
    DECLARE base_price DECIMAL(10,2) DEFAULT 50.00; -- Base price per medicine
    
    -- Count number of medicines in prescription
    SELECT COUNT(*) INTO medicine_count 
    FROM PRESCRIPTION_MEDICINE 
    WHERE prescription_id = p_prescription_id;
    
    -- Calculate total cost (base price * number of medicines)
    SET total_cost = base_price * medicine_count;
    
    RETURN total_cost;
END//

DELIMITER ;

-- Function 3: Get Patient Age Category
DELIMITER //

CREATE FUNCTION get_patient_age_category(patient_id INT) 
RETURNS VARCHAR(20)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE patient_age INT;
    DECLARE age_category VARCHAR(20);
    
    -- Calculate age using the calculate_age function
    SELECT calculate_age(date_of_birth) INTO patient_age
    FROM PATIENT 
    WHERE patient_id = patient_id;
    
    -- Determine age category
    IF patient_age < 18 THEN
        SET age_category = 'Child';
    ELSEIF patient_age BETWEEN 18 AND 35 THEN
        SET age_category = 'Young Adult';
    ELSEIF patient_age BETWEEN 36 AND 60 THEN
        SET age_category = 'Adult';
    ELSE
        SET age_category = 'Senior';
    END IF;
    
    RETURN age_category;
END//

DELIMITER ;

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Trigger 1: Auto-create prescription when appointment is completed
DELIMITER //

CREATE TRIGGER after_appointment_completed
AFTER UPDATE ON APPOINTMENT
FOR EACH ROW
BEGIN
    -- Check if status changed to 'Completed'
    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        -- Insert a new prescription
        INSERT INTO PRESCRIPTION (date, appointment_id)
        VALUES (CURDATE(), NEW.appointment_id);
    END IF;
END//

DELIMITER ;

-- Trigger 2: Update doctor rating when new appointment is completed
DELIMITER //

CREATE TRIGGER update_doctor_rating
AFTER UPDATE ON APPOINTMENT
FOR EACH ROW
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    DECLARE completed_count INT;
    
    -- Only process if appointment is completed
    IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
        -- Count completed appointments for this doctor (simulating rating calculation)
        SELECT COUNT(*) INTO completed_count
        FROM APPOINTMENT
        WHERE doctor_id = NEW.doctor_id AND status = 'Completed';
        
        -- Calculate new average rating (simplified logic)
        -- In real scenario, you would have actual ratings from patients
        SET avg_rating = 4.5 + (RAND() * 0.5); -- Random rating between 4.5-5.0
        
        -- Update doctor's rating
        UPDATE DOCTOR 
        SET ratings = avg_rating,
            updated_at = CURRENT_TIMESTAMP
        WHERE doctor_id = NEW.doctor_id;
    END IF;
END//

DELIMITER ;

-- Trigger 3: Prevent double booking for the same doctor at same time
DELIMITER //

CREATE TRIGGER prevent_double_booking
BEFORE INSERT ON APPOINTMENT
FOR EACH ROW
BEGIN
    DECLARE existing_count INT;
    
    -- Check if doctor already has appointment at same date and time
    SELECT COUNT(*) INTO existing_count
    FROM APPOINTMENT
    WHERE doctor_id = NEW.doctor_id 
    AND date = NEW.date 
    AND time_slot = NEW.time_slot
    AND status != 'Cancelled';
    
    IF existing_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor already has an appointment at this time slot';
    END IF;
END//

DELIMITER ;

-- Trigger 4: Auto-create payment when pharmacy order is created
DELIMITER //

CREATE TRIGGER after_pharmacy_order_created
AFTER INSERT ON PHARMACY_ORDER
FOR EACH ROW
BEGIN
    DECLARE prescription_cost DECIMAL(10,2);
    
    -- Calculate prescription cost using our function
    SET prescription_cost = calculate_prescription_cost(NEW.prescription_id);
    
    -- Insert payment record
    INSERT INTO PAYMENT (amount, method, date, status, order_id)
    VALUES (prescription_cost, 'UPI', CURDATE(), 'Pending', NEW.order_id);
END//

DELIMITER ;

-- Trigger 5: Update patient updated_at timestamp
DELIMITER //

CREATE TRIGGER update_patient_timestamp
BEFORE UPDATE ON PATIENT
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

DELIMITER ;

-- =============================================================================
-- INDEXES for Performance
-- =============================================================================

CREATE INDEX idx_appointment_patient ON APPOINTMENT(patient_id);
CREATE INDEX idx_appointment_doctor ON APPOINTMENT(doctor_id);
CREATE INDEX idx_appointment_date ON APPOINTMENT(date);
CREATE INDEX idx_patient_dob ON PATIENT(date_of_birth);
CREATE INDEX idx_prescription_appointment ON PRESCRIPTION(appointment_id);
CREATE INDEX idx_pharmacy_order_patient ON PHARMACY_ORDER(patient_id);
CREATE INDEX idx_pharmacy_order_prescription ON PHARMACY_ORDER(prescription_id);
CREATE INDEX idx_payment_order ON PAYMENT(order_id);
CREATE INDEX idx_payment_appointment ON PAYMENT(appointment_id);
CREATE INDEX idx_payment_test ON PAYMENT(test_id);
CREATE INDEX idx_prescription_medicine_prescription ON PRESCRIPTION_MEDICINE(prescription_id);
CREATE INDEX idx_prescription_medicine_medicine ON PRESCRIPTION_MEDICINE(medicine_id);
CREATE INDEX idx_appointment_test_appointment ON APPOINTMENT_TEST(appointment_id);
CREATE INDEX idx_appointment_test_test ON APPOINTMENT_TEST(test_id);

-- =============================================================================
-- SAMPLE DATA
-- =============================================================================

-- Insert Sample Patients (with date_of_birth instead of age)
INSERT INTO PATIENT (name, date_of_birth, gender, contact, email) VALUES
('John Doe', '1988-05-15', 'Male', '+1234567890', 'john.doe@email.com'),
('Jane Smith', '1995-08-22', 'Female', '+1234567891', 'jane.smith@email.com'),
('Mike Johnson', '1978-12-10', 'Male', '+1234567892', 'mike.johnson@email.com'),
('Sarah Wilson', '2005-03-18', 'Female', '+1234567893', 'sarah.wilson@email.com'),
('Robert Brown', '1960-07-30', 'Male', '+1234567894', 'robert.brown@email.com');

-- Insert Sample Doctors
INSERT INTO DOCTOR (name, specialty, qualifications, experience, ratings) VALUES
('Dr. Sarah Wilson', 'Cardiology', 'MD, DM Cardiology', 15, 4.8),
('Dr. Robert Brown', 'Neurology', 'MD, DM Neurology', 12, 4.6),
('Dr. Emily Davis', 'Pediatrics', 'MD, DCH', 8, 4.9);

-- Insert Sample Medicines
INSERT INTO MEDICINE (name, type, manufacturer) VALUES
('Paracetamol', 'Tablet', 'PharmaCorp'),
('Amoxicillin', 'Capsule', 'MediLife'),
('Cetirizine', 'Tablet', 'HealthPlus'),
('Vitamin C', 'Tablet', 'NutraCare'),
('Insulin', 'Injection', 'BioMed');

-- Insert Sample Lab Tests
INSERT INTO LAB_TEST (name, type, description) VALUES
('Complete Blood Count', 'Blood Test', 'Measures different components of blood'),
('Lipid Profile', 'Blood Test', 'Measures cholesterol and triglycerides'),
('Chest X-Ray', 'X-Ray', 'Checks lungs and heart'),
('MRI Brain', 'MRI', 'Detailed brain imaging');

-- =============================================================================
-- DEMONSTRATION QUERIES
-- =============================================================================

-- Query 1: Show patients with derived age using the function
SELECT 
    patient_id,
    name,
    date_of_birth,
    calculate_age(date_of_birth) as age,
    get_patient_age_category(patient_id) as age_category,
    gender,
    contact
FROM PATIENT;

-- Query 2: Create a view for patient details with derived age
CREATE VIEW patient_details AS
SELECT 
    patient_id,
    name,
    date_of_birth,
    calculate_age(date_of_birth) as age,
    get_patient_age_category(patient_id) as age_category,
    gender,
    contact,
    email,
    created_at
FROM PATIENT;

-- Query 3: Test the prescription cost function
-- First, let's create some sample data to test
INSERT INTO APPOINTMENT (date, time_slot, mode, status, patient_id, doctor_id) VALUES
('2024-01-15', '10:00:00', 'In-person', 'Completed', 1, 1);

INSERT INTO PRESCRIPTION (date, appointment_id) VALUES
('2024-01-15', 1);

INSERT INTO PRESCRIPTION_MEDICINE (prescription_id, medicine_id, dosage, frequency, duration) VALUES
(1, 1, '500mg', 'Twice daily', '5 days'),
(1, 2, '250mg', 'Three times daily', '7 days');

-- Test the cost function
SELECT 
    prescription_id,
    calculate_prescription_cost(prescription_id) as total_cost
FROM PRESCRIPTION
WHERE prescription_id = 1;

-- Query 4: Show all triggers and functions
SHOW FUNCTION STATUS WHERE Db = 'healthcare_system';
SHOW TRIGGERS FROM healthcare_system;

-- Query 5: Test the double booking prevention trigger
-- This should fail due to duplicate time slot
INSERT INTO APPOINTMENT (date, time_slot, mode, patient_id, doctor_id) VALUES
('2024-01-15', '10:00:00', 'Online', 2, 1);

-- =============================================================================
-- UTILITY QUERIES
-- =============================================================================

-- Show all tables
SHOW TABLES;

-- Describe each table structure
DESCRIBE PATIENT;
DESCRIBE DOCTOR;
DESCRIBE APPOINTMENT;
DESCRIBE PRESCRIPTION;

-- View all functions and triggers
SELECT 
    ROUTINE_NAME as 'Function Name',
    ROUTINE_TYPE as 'Type',
    CREATED as 'Created'
FROM information_schema.ROUTINES 
WHERE ROUTINE_SCHEMA = 'healthcare_system';

SELECT 
    TRIGGER_NAME as 'Trigger Name',
    ACTION_TIMING as 'Timing',
    EVENT_MANIPULATION as 'Event'
FROM information_schema.TRIGGERS 
WHERE TRIGGER_SCHEMA = 'healthcare_system';
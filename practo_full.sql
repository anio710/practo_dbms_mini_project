-- ================================================================
-- PRACTO HOSPITAL MANAGEMENT SYSTEM - COMPLETE FINAL VERSION
-- ================================================================

CREATE DATABASE IF NOT EXISTS healthcare_system;
USE healthcare_system;

-- ================================================================
-- USERS
-- ================================================================
CREATE TABLE IF NOT EXISTS USERS (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin','user') NOT NULL
);

-- ================================================================
-- PATIENT TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS PATIENT (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender ENUM('Male','Female','Other') NOT NULL,
    contact VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ================================================================
-- DOCTOR TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS DOCTOR (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    qualifications TEXT NOT NULL,
    experience INT NOT NULL,
    ratings DECIMAL(3,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (ratings >= 0 AND ratings <= 5)
);

-- ================================================================
-- APPOINTMENT TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS APPOINTMENT (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL,
    time_slot TIME NOT NULL,
    mode ENUM('Online','In-person') NOT NULL,
    status ENUM('Scheduled','Completed','Cancelled','No-show') DEFAULT 'Scheduled',
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    FOREIGN KEY (patient_id) REFERENCES PATIENT(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (doctor_id) REFERENCES DOCTOR(doctor_id) ON DELETE CASCADE,
    UNIQUE KEY unique_slot (doctor_id, date, time_slot),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ================================================================
-- PRESCRIPTION TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS PRESCRIPTION (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL,
    appointment_id INT NOT NULL UNIQUE,
    FOREIGN KEY (appointment_id) REFERENCES APPOINTMENT(appointment_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- MEDICINE TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS MEDICINE (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- LAB_TEST TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS LAB_TEST (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- PHARMACY_ORDER TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS PHARMACY_ORDER (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL,
    status ENUM('Pending', 'Confirmed', 'Shipped', 'Delivered', 'Cancelled') DEFAULT 'Pending',
    patient_id INT NOT NULL,
    prescription_id INT NOT NULL UNIQUE,
    FOREIGN KEY (patient_id) REFERENCES PATIENT(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (prescription_id) REFERENCES PRESCRIPTION(prescription_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ================================================================
-- PAYMENT TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS PAYMENT (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    amount DECIMAL(10,2) NOT NULL,
    method ENUM('Credit Card', 'Debit Card', 'UPI', 'Net Banking', 'Cash') NOT NULL,
    date DATE NOT NULL,
    status ENUM('Pending', 'Completed', 'Failed', 'Refunded') DEFAULT 'Pending',
    order_id INT NULL,
    appointment_id INT NULL,
    test_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES PHARMACY_ORDER(order_id) ON DELETE SET NULL,
    FOREIGN KEY (appointment_id) REFERENCES APPOINTMENT(appointment_id) ON DELETE SET NULL,
    FOREIGN KEY (test_id) REFERENCES LAB_TEST(test_id) ON DELETE SET NULL,
    CHECK (amount > 0)
);

-- ================================================================
-- PRESCRIPTION_MEDICINE (Many-to-Many)
-- ================================================================
CREATE TABLE IF NOT EXISTS PRESCRIPTION_MEDICINE (
    prescription_id INT NOT NULL,
    medicine_id INT NOT NULL,
    dosage VARCHAR(50),
    frequency VARCHAR(50),
    duration VARCHAR(50),
    instructions TEXT,
    PRIMARY KEY (prescription_id, medicine_id),
    FOREIGN KEY (prescription_id) REFERENCES PRESCRIPTION(prescription_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id) REFERENCES MEDICINE(medicine_id) ON DELETE CASCADE
);

-- ================================================================
-- APPOINTMENT_TEST (Many-to-Many)
-- ================================================================
CREATE TABLE IF NOT EXISTS APPOINTMENT_TEST (
    appointment_id INT NOT NULL,
    test_id INT NOT NULL,
    report_url VARCHAR(255),
    status ENUM('Scheduled', 'Processing', 'Completed') DEFAULT 'Scheduled',
    PRIMARY KEY (appointment_id, test_id),
    FOREIGN KEY (appointment_id) REFERENCES APPOINTMENT(appointment_id) ON DELETE CASCADE,
    FOREIGN KEY (test_id) REFERENCES LAB_TEST(test_id) ON DELETE CASCADE
);

-- ================================================================
-- FUNCTIONS & TRIGGERS
-- ================================================================

DELIMITER //

CREATE FUNCTION calculate_age(date_of_birth DATE)
RETURNS INT DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE());
END//

CREATE FUNCTION calculate_prescription_cost(p_prescription_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total_cost DECIMAL(10,2);
    DECLARE medicine_count INT;
    SELECT COUNT(*) INTO medicine_count FROM PRESCRIPTION_MEDICINE WHERE prescription_id=p_prescription_id;
    SET total_cost = medicine_count * 50;
    RETURN total_cost;
END//

CREATE FUNCTION get_patient_age_category(p_patient_id INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE patient_age INT;
    DECLARE category VARCHAR(20);
    SELECT calculate_age(date_of_birth) INTO patient_age FROM PATIENT WHERE patient_id=p_patient_id;
    IF patient_age < 18 THEN
        SET category='Child';
    ELSEIF patient_age BETWEEN 18 AND 35 THEN
        SET category='Young Adult';
    ELSEIF patient_age BETWEEN 36 AND 60 THEN
        SET category='Adult';
    ELSE
        SET category='Senior';
    END IF;
    RETURN category;
END//

CREATE TRIGGER after_appointment_completed
AFTER UPDATE ON APPOINTMENT
FOR EACH ROW
BEGIN
    IF NEW.status='Completed' AND OLD.status!='Completed' THEN
        IF (SELECT COUNT(*) FROM PRESCRIPTION WHERE appointment_id=NEW.appointment_id)=0 THEN
            INSERT INTO PRESCRIPTION(date,appointment_id) VALUES(CURDATE(),NEW.appointment_id);
        END IF;
    END IF;
END//

CREATE TRIGGER update_doctor_rating
AFTER UPDATE ON APPOINTMENT
FOR EACH ROW
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    IF NEW.status='Completed' THEN
        SET avg_rating = ROUND(3.5 + RAND()*1.5,2);
        UPDATE DOCTOR SET ratings=avg_rating WHERE doctor_id=NEW.doctor_id;
    END IF;
END//

CREATE TRIGGER prevent_double_booking
BEFORE INSERT ON APPOINTMENT
FOR EACH ROW
BEGIN
    DECLARE cnt INT;
    SELECT COUNT(*) INTO cnt FROM APPOINTMENT
    WHERE doctor_id=NEW.doctor_id AND date=NEW.date AND time_slot=NEW.time_slot AND status!='Cancelled';
    IF cnt>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Doctor already booked for that time slot';
    END IF;
END//

CREATE TRIGGER after_pharmacy_order_created
AFTER INSERT ON PHARMACY_ORDER
FOR EACH ROW
BEGIN
    DECLARE cost DECIMAL(10,2);
    SET cost = calculate_prescription_cost(NEW.prescription_id);
    INSERT INTO PAYMENT(amount,method,date,status,order_id)
    VALUES(cost,'UPI',CURDATE(),'Pending',NEW.order_id);
END//

CREATE TRIGGER update_patient_timestamp
BEFORE UPDATE ON PATIENT
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

DELIMITER ;

-- ================================================================
-- DEFAULT USERS
-- ================================================================
INSERT INTO USERS(username,password,role) VALUES
('admin','admin123','admin'),
('user','user123','user');

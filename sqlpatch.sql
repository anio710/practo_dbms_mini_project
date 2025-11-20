USE healthcare_system;

-- ============================================================
-- 1️⃣ Add missing user_id column to PATIENT table (safe patch)
-- ============================================================
ALTER TABLE PATIENT 
ADD COLUMN IF NOT EXISTS user_id INT AFTER patient_id;

-- If foreign key constraint not yet added, add it safely
SET @fk_exists := (
  SELECT COUNT(*) 
  FROM information_schema.REFERENTIAL_CONSTRAINTS 
  WHERE CONSTRAINT_NAME = 'fk_patient_user'
  AND CONSTRAINT_SCHEMA = DATABASE()
);
SET @sql := IF(@fk_exists = 0, 
  'ALTER TABLE PATIENT ADD CONSTRAINT fk_patient_user FOREIGN KEY (user_id) REFERENCES USERS(user_id) ON DELETE CASCADE;', 
  'SELECT "Foreign key already exists"');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ============================================================
-- 2️⃣ Update user_id for existing patients (manual mapping)
-- ============================================================
-- ⚠️ Replace these values with your actual users' IDs and emails or names.
-- You can check USERS table with: SELECT * FROM USERS;

UPDATE PATIENT SET user_id = 8 WHERE email = 'austi@gmail.com';
UPDATE PATIENT SET user_id = 13 WHERE email = 'chin@gmail.com';
-- Add more mappings here if needed
-- Example:
-- UPDATE PATIENT SET user_id = 12 WHERE email = 'chi@gmail.com';

-- ============================================================
-- 3️⃣ Verify consistency (optional)
-- ============================================================
SELECT p.patient_id, p.name, p.email, p.user_id, u.username, u.role
FROM PATIENT p
LEFT JOIN USERS u ON p.user_id = u.user_id;

-- ============================================================
-- ✅ Done! This ensures all "mine" routes work correctly
-- /prescriptions/mine
-- /orders
-- /labtests/request
-- /labtests/mine
-- ============================================================

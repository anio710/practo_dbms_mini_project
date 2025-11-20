const bcrypt = require('bcryptjs');
const mysql = require('mysql2/promise');

(async () => {
  const conn = await mysql.createConnection({
    host: 'localhost',
    user: 'root',           // your MySQL username
    password: 'Anirudh@123',           // your MySQL password
    database: 'healthcare_system'
  });

  const plainPassword = 'admin123';
  const hashed = await bcrypt.hash(plainPassword, 10);

  console.log('🔐 New bcrypt hash for admin123:', hashed);

  await conn.query(
    'UPDATE USERS SET password = ?, role = "admin" WHERE username = "admin"',
    [hashed]
  );

  console.log('✅ Admin password reset successfully!');
  await conn.end();
})();

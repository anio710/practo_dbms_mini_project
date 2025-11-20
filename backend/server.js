const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const doctors = require('./routes/doctors');
const appointments = require('./routes/appointments');
const medicines = require('./routes/medicines');
const prescriptions = require('./routes/prescriptions');
const orders = require('./routes/orders');
const payments = require('./routes/payments');
const labtests = require('./routes/labtests');
const patients = require('./routes/patients');

const app = express();
app.use(cors());
app.use(bodyParser.json());

const dbIntelligence = require("./routes/dbintelligence");
app.use("/api/dbintelligence", dbIntelligence);

// ensure upload dir exists
const uploadDir = process.env.UPLOAD_DIR || 'uploads';
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));


app.use('/api/auth', authRoutes);
app.use('/api/doctors', doctors);
app.use('/api/appointments', appointments);
app.use('/api/medicines', medicines);
app.use('/api/prescriptions', prescriptions);
app.use('/api/orders', orders);
app.use('/api/payments', payments);
app.use('/api/labtests', labtests);
app.use('/api/patients', patients);

app.get('/', (req, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log('Server listening on', PORT));

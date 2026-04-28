require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');
const rateLimit = require('express-rate-limit');
const { connectDB } = require('./src/config/database');
const logger  = require('./src/utils/logger');
const errorHandler = require('./src/middleware/errorHandler');

// Route imports
const authRoutes     = require('./src/routes/auth');
const productRoutes  = require('./src/routes/products');
const saleRoutes     = require('./src/routes/sales');
const customerRoutes = require('./src/routes/customers');
const supplierRoutes = require('./src/routes/suppliers');
const purchaseRoutes = require('./src/routes/purchases');
const expenseRoutes  = require('./src/routes/expenses');
const reportRoutes   = require('./src/routes/reports');
const versionRoutes  = require('./src/routes/appVersion');

const app = express();

// Connect to PostgreSQL
connectDB();

// Middleware
app.use(helmet());
app.use(cors({ origin: '*', methods: ['GET','POST','PUT','DELETE','PATCH'] }));
app.use(morgan('combined', { stream: { write: msg => logger.info(msg.trim()) } }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/api/', rateLimit({ windowMs: 15 * 60 * 1000, max: 500 }));

// Health check
app.get('/health', async (req, res) => {
  const { query } = require('./src/config/database');
  try {
    await query('SELECT 1');
    res.json({ status: 'OK', db: 'PostgreSQL connected', time: new Date().toISOString() });
  } catch {
    res.status(500).json({ status: 'ERROR', db: 'PostgreSQL disconnected' });
  }
});

// API routes
app.use('/api/auth',      authRoutes);
app.use('/api/products',  productRoutes);
app.use('/api/sales',     saleRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/suppliers', supplierRoutes);
app.use('/api/purchases', purchaseRoutes);
app.use('/api/expenses',  expenseRoutes);
app.use('/api/reports',   reportRoutes);
app.use('/api/version',   versionRoutes);

app.use((req, res) => res.status(404).json({ success: false, message: 'Route not found' }));
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
const server = app.listen(PORT, () =>
  logger.info(`Server running on port ${PORT} — PostgreSQL backend`)
);

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    logger.error(
      `Port ${PORT} is already in use.\n` +
      `  → Kill the other process first, or set a different PORT in .env\n` +
      `  → Windows: netstat -ano | findstr :${PORT}  then  taskkill /PID <pid> /F`
    );
    process.exit(1);
  } else {
    throw err;
  }
});

module.exports = app;

const { Pool } = require('pg');
const logger = require('../utils/logger');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production'
    ? { rejectUnauthorized: false }   // required for Supabase / Neon / Railway
    : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => logger.error('Unexpected pg pool error', err));

const connectDB = async () => {
  try {
    const client = await pool.connect();
    const { rows } = await client.query('SELECT version()');
    logger.info(`PostgreSQL connected: ${rows[0].version.split(',')[0]}`);
    client.release();
  } catch (err) {
    logger.error(`PostgreSQL connection error: ${err.message}`);
    process.exit(1);
  }
};

// Convenience helpers
const query  = (text, params) => pool.query(text, params);
const getClient = () => pool.connect();

module.exports = { connectDB, query, getClient, pool };

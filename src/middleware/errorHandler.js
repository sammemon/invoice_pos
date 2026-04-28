const logger = require('../utils/logger');

const PG_CODES = {
  '23505': (err) => {
    const detail = err.detail || '';
    const field  = detail.match(/\((.+?)\)/)?.[1] || 'field';
    return `${field} already exists`;
  },
  '23503': () => 'Referenced record does not exist',
  '23502': (err) => `${err.column} is required`,
  '22P02': () => 'Invalid UUID format',
  '23514': (err) => `Value violates constraint: ${err.constraint}`,
};

const errorHandler = (err, req, res, next) => {
  logger.error(err.message, { stack: err.stack, code: err.code });

  // PostgreSQL errors
  if (err.code && PG_CODES[err.code]) {
    return res.status(400).json({ success: false, message: PG_CODES[err.code](err) });
  }

  // Business logic errors with explicit statusCode
  if (err.statusCode) {
    return res.status(err.statusCode).json({ success: false, message: err.message });
  }

  // Validation errors from express-validator
  if (err.type === 'validation') {
    return res.status(400).json({ success: false, message: err.message });
  }

  res.status(500).json({
    success: false,
    message: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
  });
};

module.exports = errorHandler;

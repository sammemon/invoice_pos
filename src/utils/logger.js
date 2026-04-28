const { createLogger, format, transports } = require('winston');
const path = require('path');
const fs   = require('fs');

// When running as a pkg .exe, __dirname is inside the snapshot (read-only).
// Write logs next to the executable instead.
const logsDir = (() => {
  const exeDir = path.dirname(process.execPath || '');
  // If execPath looks like a real directory (not the pkg snapshot), use it.
  const candidate = path.join(exeDir, 'logs');
  try { fs.mkdirSync(candidate, { recursive: true }); return candidate; } catch (_) {}
  // Fallback: current working directory
  try {
    const cwd = path.join(process.cwd(), 'logs');
    fs.mkdirSync(cwd, { recursive: true });
    return cwd;
  } catch (_) { return null; }
})();

const consoleTransport = new transports.Console({
  level: 'info',   // always show info+ in console regardless of NODE_ENV
  format: format.combine(
    format.colorize(),
    format.timestamp({ format: 'HH:mm:ss' }),
    format.printf(({ timestamp, level, message }) => `${timestamp} ${level}: ${message}`)
  ),
});

const fileTransports = logsDir ? [
  new transports.File({ filename: path.join(logsDir, 'error.log'),    level: 'error' }),
  new transports.File({ filename: path.join(logsDir, 'combined.log') }),
] : [];

const logger = createLogger({
  level: 'info',
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.errors({ stack: true }),
    format.printf(({ timestamp, level, message, stack }) =>
      stack ? `[${timestamp}] ${level.toUpperCase()}: ${message}\n${stack}`
            : `[${timestamp}] ${level.toUpperCase()}: ${message}`)
  ),
  transports: [consoleTransport, ...fileTransports],
});

module.exports = logger;

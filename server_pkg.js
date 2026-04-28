// Entry point used by pkg — resolves .env relative to the exe, not the snapshot
console.log('Invoice POS Server starting...');
const path = require('path');
const fs   = require('fs');

// When running as a pkg executable, __dirname points inside the snapshot.
// process.execPath points to the actual .exe location.
const exeDir = path.dirname(process.execPath);
const envPath = path.join(exeDir, '.env');

if (fs.existsSync(envPath)) {
  require('dotenv').config({ path: envPath });
} else {
  // Fallback: try working directory
  require('dotenv').config();
}

require('./server.js');

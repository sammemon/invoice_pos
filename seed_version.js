require('dotenv').config();
const { query } = require('./src/config/database');
const VER     = '1.0.5';
const WIN_URL = 'https://github.com/sammemon/invoice_pos/releases/download/v1.0.5/InvoicePOS_Setup_v1.0.5.exe';
const APK_URL = 'https://github.com/sammemon/invoice_pos/releases/download/v1.0.5/app-arm64-v8a-release.apk';
const NOTES   = 'Installer elevation fixed (no more schtasks error), backend auto-starts from Startup folder';
(async () => {
  await query('UPDATE app_versions SET is_active = false');
  await query('INSERT INTO app_versions (platform,version,download_url,release_notes,is_active) VALUES ($1,$2,$3,$4,true)', ['windows',VER,WIN_URL,NOTES]);
  await query('INSERT INTO app_versions (platform,version,download_url,release_notes,is_active) VALUES ($1,$2,$3,$4,true)', ['android',VER,APK_URL,NOTES]);
  const {rows} = await query('SELECT platform,version,is_active FROM app_versions ORDER BY created_at DESC LIMIT 4');
  rows.forEach(r => console.log(`[${r.platform}] v${r.version} active=${r.is_active}`));
  console.log('✅ v'+VER); process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });

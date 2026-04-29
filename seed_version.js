require('dotenv').config();
const { query } = require('./src/config/database');

(async () => {
  await query(`
    INSERT INTO app_versions (platform, version, download_url, release_notes, is_active)
    VALUES ('windows', '1.0.0',
      'https://github.com/sammemon/invoice_pos/releases/download/v1.0.0/InvoicePOS_Setup_v1.0.0.exe',
      'Initial release - Invoice & POS Billing', true)
    ON CONFLICT DO NOTHING
  `);
  await query(`
    INSERT INTO app_versions (platform, version, download_url, release_notes, is_active)
    VALUES ('android', '1.0.0',
      'https://github.com/sammemon/invoice_pos/releases/download/v1.0.0/app-arm64-v8a-release.apk',
      'Initial release - Invoice & POS Billing', true)
    ON CONFLICT DO NOTHING
  `);
  const { rows } = await query('SELECT platform, version, is_active FROM app_versions');
  console.log('Seeded:', rows);
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });

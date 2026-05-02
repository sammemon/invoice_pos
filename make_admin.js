require('dotenv').config();
const { query } = require('./src/config/database');
(async () => {
  await query("UPDATE users SET role = 'admin'");
  const { rows } = await query('SELECT name, email, role FROM users');
  rows.forEach(r => console.log(`  ${r.name} | ${r.email} | role: ${r.role}`));
  console.log('\n✅ All users upgraded to admin (Premium Member)');
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });

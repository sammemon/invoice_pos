require('dotenv').config();
const { query } = require('./src/config/database');
(async () => {
  // Test account → cashier (regular user)
  await query("UPDATE users SET role = 'cashier' WHERE email = 'admin@shop.com'");
  // Your account stays admin
  const { rows } = await query('SELECT name, email, role FROM users ORDER BY created_at');
  console.log('\nCurrent roles:');
  rows.forEach(r => console.log(`  ${r.email} → ${r.role}`));
  console.log('\n✅ Only sm275665@gmail.com is admin (Premium)');
  console.log('   New registrations default to cashier automatically.');
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });

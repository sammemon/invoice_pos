const router = require('express').Router();
const { query: db } = require('../config/database');
const { protect } = require('../middleware/auth');

router.use(protect);

router.get('/', async (req, res, next) => {
  try {
    const { search } = req.query;
    const values = [req.user.id];
    let where = 'user_id = $1 AND is_active = true';
    if (search) { where += ' AND (name ILIKE $2 OR phone ILIKE $2)'; values.push(`%${search}%`); }
    const { rows } = await db(`SELECT * FROM suppliers WHERE ${where} ORDER BY name`, values);
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  try {
    const { name, phone, email, address, company, notes } = req.body;
    if (!name) return res.status(400).json({ success: false, message: 'Name required' });
    const { rows } = await db(
      `INSERT INTO suppliers (user_id, name, phone, email, address, company, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [req.user.id, name, phone||null, email||null, address||null, company||null, notes||null]
    );
    res.status(201).json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db(
      'SELECT * FROM suppliers WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Not found' });
    const { rows: purchases } = await db(
      'SELECT * FROM purchases WHERE supplier_id = $1 ORDER BY purchase_date DESC LIMIT 20', [req.params.id]);
    res.json({ success: true, data: rows[0], purchases });
  } catch (err) { next(err); }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { name, phone, email, address, company, notes } = req.body;
    const { rows } = await db(
      `UPDATE suppliers SET
         name = COALESCE($1,name), phone = COALESCE($2,phone),
         email = COALESCE($3,email), address = COALESCE($4,address),
         company = COALESCE($5,company), notes = COALESCE($6,notes)
       WHERE id = $7 AND user_id = $8 RETURNING *`,
      [name, phone, email, address, company, notes, req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    await db('UPDATE suppliers SET is_active = false WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    res.json({ success: true, message: 'Supplier deleted' });
  } catch (err) { next(err); }
});

router.post('/:id/payment', async (req, res, next) => {
  try {
    const { amount, paymentMethod = 'cash', notes } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ success: false, message: 'Valid amount required' });
    const { rows } = await db(
      `INSERT INTO payments (user_id, type, supplier_id, amount, payment_method, notes)
       VALUES ($1,'supplier',$2,$3,$4,$5) RETURNING *`,
      [req.user.id, req.params.id, amount, paymentMethod, notes||null]
    );
    await db('UPDATE suppliers SET current_balance = current_balance - $1 WHERE id = $2', [amount, req.params.id]);
    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

module.exports = router;

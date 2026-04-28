const router = require('express').Router();
const { query: db } = require('../config/database');
const { protect } = require('../middleware/auth');

router.use(protect);

// GET /api/customers
router.get('/', async (req, res, next) => {
  try {
    const { search, page = 1, limit = 100 } = req.query;
    const values = [req.user.id];
    let where = 'user_id = $1 AND is_active = true';
    if (search) {
      where += ` AND (name ILIKE $2 OR phone ILIKE $2)`;
      values.push(`%${search}%`);
    }
    const offset = (page - 1) * limit;
    const [dataRes, countRes] = await Promise.all([
      db(`SELECT * FROM customers WHERE ${where} ORDER BY name LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
         [...values, limit, offset]),
      db(`SELECT COUNT(*) FROM customers WHERE ${where}`, values),
    ]);
    res.json({ success: true, data: dataRes.rows, total: parseInt(countRes.rows[0].count) });
  } catch (err) { next(err); }
});

// POST /api/customers
router.post('/', async (req, res, next) => {
  try {
    const { name, phone, email, address, notes } = req.body;
    if (!name) return res.status(400).json({ success: false, message: 'Name is required' });
    const { rows } = await db(
      `INSERT INTO customers (user_id, name, phone, email, address, notes)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [req.user.id, name, phone||null, email||null, address||null, notes||null]
    );
    res.status(201).json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

// GET /api/customers/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db(
      'SELECT * FROM customers WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Customer not found' });
    const [sales, payments] = await Promise.all([
      db('SELECT * FROM sales WHERE customer_id = $1 ORDER BY sale_date DESC LIMIT 20', [req.params.id]),
      db('SELECT * FROM payments WHERE customer_id = $1 ORDER BY payment_date DESC LIMIT 20', [req.params.id]),
    ]);
    res.json({ success: true, data: rows[0], sales: sales.rows, payments: payments.rows });
  } catch (err) { next(err); }
});

// PUT /api/customers/:id
router.put('/:id', async (req, res, next) => {
  try {
    const { name, phone, email, address, notes } = req.body;
    const { rows } = await db(
      `UPDATE customers SET
         name = COALESCE($1, name), phone = COALESCE($2, phone),
         email = COALESCE($3, email), address = COALESCE($4, address),
         notes = COALESCE($5, notes)
       WHERE id = $6 AND user_id = $7 RETURNING *`,
      [name, phone, email, address, notes, req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

// DELETE /api/customers/:id
router.delete('/:id', async (req, res, next) => {
  try {
    await db('UPDATE customers SET is_active = false WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    res.json({ success: true, message: 'Customer deleted' });
  } catch (err) { next(err); }
});

// POST /api/customers/:id/payment
router.post('/:id/payment', async (req, res, next) => {
  try {
    const { amount, paymentMethod = 'cash', notes } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ success: false, message: 'Valid amount required' });
    const { rows } = await db(
      `INSERT INTO payments (user_id, type, customer_id, amount, payment_method, notes)
       VALUES ($1,'customer',$2,$3,$4,$5) RETURNING *`,
      [req.user.id, req.params.id, amount, paymentMethod, notes||null]
    );
    await db('UPDATE customers SET current_balance = current_balance - $1 WHERE id = $2', [amount, req.params.id]);
    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

module.exports = router;

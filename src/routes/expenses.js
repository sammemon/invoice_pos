const router = require('express').Router();
const { query: db } = require('../config/database');
const { protect } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

router.use(protect);

router.get('/', async (req, res, next) => {
  try {
    const { startDate, endDate, category, page = 1, limit = 50 } = req.query;
    const values = [req.user.id];
    let where = 'user_id = $1';
    let idx = 2;
    if (startDate) { where += ` AND expense_date >= $${idx++}`; values.push(startDate); }
    if (endDate)   { where += ` AND expense_date <= $${idx++}`; values.push(endDate); }
    if (category)  { where += ` AND category = $${idx++}`; values.push(category); }

    const offset = (page - 1) * limit;
    const [dataRes, countRes, sumRes] = await Promise.all([
      db(`SELECT * FROM expenses WHERE ${where} ORDER BY expense_date DESC LIMIT $${idx} OFFSET $${idx + 1}`,
         [...values, limit, offset]),
      db(`SELECT COUNT(*) FROM expenses WHERE ${where}`, values),
      db(`SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE ${where}`, values),
    ]);
    res.json({
      success: true,
      data: dataRes.rows,
      total: parseInt(countRes.rows[0].count),
      totalAmount: parseFloat(sumRes.rows[0].total),
    });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  try {
    const { title, category = 'General', amount, description, expenseDate, paymentMethod = 'cash', syncId } = req.body;
    if (!title || !amount) return res.status(400).json({ success: false, message: 'title and amount required' });

    // Duplicate check for offline sync
    if (syncId) {
      const dup = await db('SELECT id FROM expenses WHERE sync_id = $1', [syncId]);
      if (dup.rows.length) return res.json({ success: true, data: dup.rows[0], duplicate: true });
    }

    const { rows } = await db(
      `INSERT INTO expenses (user_id, title, category, amount, description, expense_date, payment_method, sync_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.user.id, title, category, amount, description||null,
       expenseDate ? new Date(expenseDate) : new Date(), paymentMethod, syncId || uuidv4()]
    );
    res.status(201).json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { title, category, amount, description, expenseDate, paymentMethod } = req.body;
    const { rows } = await db(
      `UPDATE expenses SET
         title = COALESCE($1,title), category = COALESCE($2,category),
         amount = COALESCE($3,amount), description = COALESCE($4,description),
         expense_date = COALESCE($5,expense_date), payment_method = COALESCE($6,payment_method)
       WHERE id = $7 AND user_id = $8 RETURNING *`,
      [title, category, amount, description,
       expenseDate ? new Date(expenseDate) : null, paymentMethod,
       req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    await db('DELETE FROM expenses WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    res.json({ success: true, message: 'Deleted' });
  } catch (err) { next(err); }
});

router.get('/categories', async (req, res, next) => {
  try {
    const { rows } = await db(
      'SELECT DISTINCT category FROM expenses WHERE user_id = $1 ORDER BY category', [req.user.id]);
    res.json({ success: true, data: rows.map(r => r.category) });
  } catch (err) { next(err); }
});

router.post('/bulk-sync', async (req, res, next) => {
  try {
    const { expenses } = req.body;
    const results = [];
    for (const e of expenses) {
      const dup = await db('SELECT id FROM expenses WHERE sync_id = $1', [e.syncId]);
      if (!dup.rows.length) {
        const { rows } = await db(
          `INSERT INTO expenses (user_id, title, category, amount, description, expense_date, payment_method, sync_id)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
          [req.user.id, e.title, e.category||'General', e.amount, e.description||null,
           e.expenseDate ? new Date(e.expenseDate) : new Date(), e.paymentMethod||'cash', e.syncId]
        );
        results.push({ syncId: e.syncId, status: 'created', id: rows[0].id });
      } else {
        results.push({ syncId: e.syncId, status: 'duplicate' });
      }
    }
    res.json({ success: true, results });
  } catch (err) { next(err); }
});

module.exports = router;

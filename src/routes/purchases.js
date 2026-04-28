const router    = require('express').Router();
const { query: db, getClient } = require('../config/database');
const { protect } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

router.use(protect);

router.get('/', async (req, res, next) => {
  try {
    const { startDate, endDate, supplier, page = 1, limit = 20 } = req.query;
    const values = [req.user.id];
    let where = 'p.user_id = $1';
    let idx = 2;
    if (startDate) { where += ` AND p.purchase_date >= $${idx++}`; values.push(startDate); }
    if (endDate)   { where += ` AND p.purchase_date <= $${idx++}`; values.push(endDate); }
    if (supplier)  { where += ` AND p.supplier_id = $${idx++}`; values.push(supplier); }

    const offset = (page - 1) * limit;
    const [dataRes, countRes] = await Promise.all([
      db(`SELECT p.*, s.phone AS supplier_phone
          FROM purchases p
          LEFT JOIN suppliers s ON s.id = p.supplier_id
          WHERE ${where} ORDER BY p.purchase_date DESC
          LIMIT $${idx} OFFSET $${idx + 1}`,
         [...values, limit, offset]),
      db(`SELECT COUNT(*) FROM purchases p WHERE ${where}`, values),
    ]);
    res.json({ success: true, data: dataRes.rows, total: parseInt(countRes.rows[0].count) });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  const client = await getClient();
  try {
    await client.query('BEGIN');
    const { items, supplierId, paidAmount = 0, notes, syncId } = req.body;

    if (syncId) {
      const dup = await client.query('SELECT id FROM purchases WHERE sync_id = $1', [syncId]);
      if (dup.rows.length) {
        await client.query('ROLLBACK');
        const ex = await db('SELECT * FROM purchases WHERE sync_id = $1', [syncId]);
        return res.json({ success: true, data: ex.rows[0], duplicate: true });
      }
    }

    let totalAmount = 0;
    const enriched = [];
    for (const item of items) {
      const { rows } = await client.query(
        'SELECT * FROM products WHERE id = $1 AND user_id = $2', [item.productId, req.user.id]);
      if (!rows[0]) throw new Error(`Product ${item.productId} not found`);
      const lineTotal = item.costPrice * item.quantity;
      totalAmount += lineTotal;
      enriched.push({ productId: rows[0].id, productName: rows[0].name,
                      quantity: item.quantity, costPrice: item.costPrice, total: lineTotal });
      await client.query(
        'UPDATE products SET quantity = quantity + $1, purchase_price = $2 WHERE id = $3',
        [item.quantity, item.costPrice, rows[0].id]
      );
    }

    const dueAmount  = Math.max(0, totalAmount - paidAmount);
    const payStatus  = paidAmount >= totalAmount ? 'paid' : paidAmount > 0 ? 'partial' : 'unpaid';
    const purchNum   = `PUR-${Date.now().toString(36).toUpperCase()}`;
    const finalSyncId = syncId || uuidv4();

    let supplierName = null;
    if (supplierId) {
      const { rows: sr } = await client.query('SELECT name FROM suppliers WHERE id = $1', [supplierId]);
      supplierName = sr[0]?.name ?? null;
      if (dueAmount > 0)
        await client.query('UPDATE suppliers SET current_balance = current_balance + $1 WHERE id = $2', [dueAmount, supplierId]);
    }

    const { rows: pRows } = await client.query(
      `INSERT INTO purchases
         (user_id, purchase_number, supplier_id, supplier_name,
          total_amount, paid_amount, due_amount, payment_status, notes, sync_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [req.user.id, purchNum, supplierId||null, supplierName,
       totalAmount, paidAmount, dueAmount, payStatus, notes||null, finalSyncId]
    );
    const purchase = pRows[0];

    for (const item of enriched) {
      await client.query(
        `INSERT INTO purchase_items (purchase_id, product_id, product_name, quantity, cost_price, total)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [purchase.id, item.productId, item.productName, item.quantity, item.costPrice, item.total]
      );
    }

    await client.query('COMMIT');
    const { rows: itemRows } = await db('SELECT * FROM purchase_items WHERE purchase_id = $1', [purchase.id]);
    res.status(201).json({ success: true, data: { ...purchase, items: itemRows } });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally { client.release(); }
});

router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db(
      'SELECT * FROM purchases WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Not found' });
    const { rows: items } = await db('SELECT * FROM purchase_items WHERE purchase_id = $1', [req.params.id]);
    res.json({ success: true, data: { ...rows[0], items } });
  } catch (err) { next(err); }
});

module.exports = router;

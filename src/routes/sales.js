const router    = require('express').Router();
const { query: db, getClient } = require('../config/database');
const { protect } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

router.use(protect);

// GET /api/sales
router.get('/', async (req, res, next) => {
  try {
    const { startDate, endDate, customer, paymentStatus, page = 1, limit = 20 } = req.query;
    const values = [req.user.id];
    let where = 's.user_id = $1';
    let idx = 2;

    if (startDate) { where += ` AND s.sale_date >= $${idx++}`; values.push(startDate); }
    if (endDate)   { where += ` AND s.sale_date <= $${idx++}`; values.push(endDate); }
    if (customer)  { where += ` AND s.customer_id = $${idx++}`; values.push(customer); }
    if (paymentStatus) { where += ` AND s.payment_status = $${idx++}`; values.push(paymentStatus); }

    const offset = (page - 1) * limit;
    const [dataRes, countRes] = await Promise.all([
      db(`SELECT s.*, c.phone AS customer_phone
          FROM sales s
          LEFT JOIN customers c ON c.id = s.customer_id
          WHERE ${where}
          ORDER BY s.sale_date DESC
          LIMIT $${idx} OFFSET $${idx + 1}`,
         [...values, limit, offset]),
      db(`SELECT COUNT(*) FROM sales s WHERE ${where}`, values),
    ]);

    res.json({ success: true, data: dataRes.rows, total: parseInt(countRes.rows[0].count), page: +page });
  } catch (err) { next(err); }
});

// POST /api/sales
router.post('/', async (req, res, next) => {
  const client = await getClient();
  try {
    await client.query('BEGIN');

    const { items, customerId, paidAmount = 0, paymentMethod = 'cash',
            discountAmount = 0, taxAmount = 0, notes, syncId } = req.body;

    // Duplicate-check for offline sync
    if (syncId) {
      const dup = await client.query('SELECT id FROM sales WHERE sync_id = $1', [syncId]);
      if (dup.rows.length) {
        await client.query('ROLLBACK');
        const existing = await db('SELECT * FROM sales WHERE sync_id = $1', [syncId]);
        return res.json({ success: true, data: existing.rows[0], duplicate: true });
      }
    }

    // Validate stock & build line items
    let subTotal = 0;
    const enriched = [];
    for (const item of items) {
      const { rows } = await client.query(
        'SELECT * FROM products WHERE id = $1 AND user_id = $2 FOR UPDATE',
        [item.productId, req.user.id]
      );
      const product = rows[0];
      if (!product) throw Object.assign(new Error(`Product ${item.productId} not found`), { statusCode: 404 });
      if (product.quantity < item.quantity)
        throw Object.assign(new Error(`Insufficient stock for "${product.name}" (have ${product.quantity})`), { statusCode: 422 });

      const lineTotal = (item.sellingPrice ?? +product.selling_price) * item.quantity - (item.discount ?? 0);
      subTotal += lineTotal;
      enriched.push({
        productId: product.id, productName: product.name,
        quantity: item.quantity,
        purchasePrice: +product.purchase_price,
        sellingPrice: item.sellingPrice ?? +product.selling_price,
        discount: item.discount ?? 0,
        total: lineTotal,
      });
      await client.query('UPDATE products SET quantity = quantity - $1 WHERE id = $2', [item.quantity, product.id]);
    }

    const grandTotal  = subTotal - discountAmount + taxAmount;
    const dueAmount   = Math.max(0, grandTotal - paidAmount);
    const payStatus   = paidAmount >= grandTotal ? 'paid' : paidAmount > 0 ? 'partial' : 'unpaid';
    const invoiceNum  = `INV-${Date.now().toString(36).toUpperCase()}`;
    const finalSyncId = syncId || uuidv4();

    // Customer name + update balance
    let customerName = null;
    if (customerId) {
      const { rows: crows } = await client.query('SELECT name FROM customers WHERE id = $1', [customerId]);
      customerName = crows[0]?.name ?? null;
      if (dueAmount > 0)
        await client.query('UPDATE customers SET current_balance = current_balance + $1 WHERE id = $2', [dueAmount, customerId]);
    }

    const { rows: saleRows } = await client.query(
      `INSERT INTO sales
         (user_id, invoice_number, customer_id, customer_name,
          sub_total, discount_amount, tax_amount, grand_total,
          paid_amount, due_amount, payment_method, payment_status, notes, sync_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING *`,
      [req.user.id, invoiceNum, customerId || null, customerName,
       subTotal, discountAmount, taxAmount, grandTotal,
       paidAmount, dueAmount, paymentMethod, payStatus, notes || null, finalSyncId]
    );
    const sale = saleRows[0];

    for (const item of enriched) {
      await client.query(
        `INSERT INTO sale_items
           (sale_id, product_id, product_name, quantity, purchase_price, selling_price, discount, total)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [sale.id, item.productId, item.productName, item.quantity,
         item.purchasePrice, item.sellingPrice, item.discount, item.total]
      );
    }

    await client.query('COMMIT');

    // Return sale with items
    const { rows: itemRows } = await db('SELECT * FROM sale_items WHERE sale_id = $1', [sale.id]);
    res.status(201).json({ success: true, data: { ...sale, items: itemRows } });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally { client.release(); }
});

// GET /api/sales/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db('SELECT * FROM sales WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Sale not found' });
    const { rows: items } = await db('SELECT * FROM sale_items WHERE sale_id = $1', [req.params.id]);
    res.json({ success: true, data: { ...rows[0], items } });
  } catch (err) { next(err); }
});

// POST /api/sales/bulk-sync (offline sync)
router.post('/bulk-sync', async (req, res, next) => {
  try {
    const { sales } = req.body;
    const results = [];
    for (const s of sales) {
      const dup = await db('SELECT id FROM sales WHERE sync_id = $1', [s.syncId]);
      if (!dup.rows.length) {
        // Simplified insert without stock deduction (already done offline)
        const { rows } = await db(
          `INSERT INTO sales
             (user_id, invoice_number, customer_id, customer_name,
              sub_total, discount_amount, tax_amount, grand_total,
              paid_amount, due_amount, payment_method, payment_status, notes, sync_id)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING id`,
          [req.user.id, s.invoiceNumber || `INV-${Date.now().toString(36)}`,
           s.customerId || null, s.customerName || null,
           s.subTotal, s.discountAmount || 0, s.taxAmount || 0, s.grandTotal,
           s.paidAmount || 0, s.dueAmount || 0, s.paymentMethod || 'cash',
           s.paymentStatus || 'paid', s.notes || null, s.syncId]
        );
        results.push({ syncId: s.syncId, status: 'created', id: rows[0].id });
      } else {
        results.push({ syncId: s.syncId, status: 'duplicate' });
      }
    }
    res.json({ success: true, results });
  } catch (err) { next(err); }
});

module.exports = router;

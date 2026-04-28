const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { query: db } = require('../config/database');
const { protect } = require('../middleware/auth');

router.use(protect);

// GET /api/products
router.get('/', async (req, res, next) => {
  try {
    const { search, category, page = 1, limit = 100 } = req.query;
    const offset = (page - 1) * limit;
    const values = [req.user.id];
    let where = 'user_id = $1 AND is_active = true';
    let idx = 2;

    if (search) {
      where += ` AND (name ILIKE $${idx} OR barcode ILIKE $${idx} OR sku ILIKE $${idx})`;
      values.push(`%${search}%`); idx++;
    }
    if (category) { where += ` AND category = $${idx}`; values.push(category); idx++; }

    const [dataRes, countRes, lowRes] = await Promise.all([
      db(`SELECT * FROM products WHERE ${where} ORDER BY name LIMIT $${idx} OFFSET $${idx + 1}`,
         [...values, limit, offset]),
      db(`SELECT COUNT(*) FROM products WHERE ${where}`, values),
      db(`SELECT COUNT(*) FROM products WHERE user_id = $1 AND is_active = true AND quantity <= min_stock_level`,
         [req.user.id]),
    ]);

    res.json({
      success: true,
      data: dataRes.rows,
      total: parseInt(countRes.rows[0].count),
      page: +page,
      lowStockCount: parseInt(lowRes.rows[0].count),
    });
  } catch (err) { next(err); }
});

// GET /api/products/low-stock
router.get('/low-stock', async (req, res, next) => {
  try {
    const { rows } = await db(
      `SELECT * FROM products WHERE user_id = $1 AND is_active = true AND quantity <= min_stock_level ORDER BY quantity ASC`,
      [req.user.id]
    );
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
});

// GET /api/products/categories
router.get('/categories', async (req, res, next) => {
  try {
    const { rows } = await db(
      `SELECT DISTINCT category FROM products WHERE user_id = $1 AND is_active = true ORDER BY category`,
      [req.user.id]
    );
    res.json({ success: true, data: rows.map(r => r.category) });
  } catch (err) { next(err); }
});

// POST /api/products
router.post('/', [
  body('name').notEmpty().trim(),
  body('purchasePrice').isNumeric(),
  body('sellingPrice').isNumeric(),
], async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });
  try {
    const { name, sku, barcode, category = 'General', description,
            purchasePrice, sellingPrice, quantity = 0, minStockLevel = 5, unit = 'pcs' } = req.body;
    const { rows } = await db(
      `INSERT INTO products
         (user_id, name, sku, barcode, category, description,
          purchase_price, selling_price, quantity, min_stock_level, unit)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
      [req.user.id, name, sku||null, barcode||null, category, description||null,
       purchasePrice, sellingPrice, quantity, minStockLevel, unit]
    );
    res.status(201).json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

// GET /api/products/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db(
      `SELECT * FROM products WHERE id = $1 AND user_id = $2`, [req.params.id, req.user.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

// PUT /api/products/:id
router.put('/:id', async (req, res, next) => {
  try {
    const { name, sku, barcode, category, description,
            purchasePrice, sellingPrice, quantity, minStockLevel, unit } = req.body;
    const { rows } = await db(
      `UPDATE products SET
         name = COALESCE($1, name), sku = COALESCE($2, sku),
         barcode = COALESCE($3, barcode), category = COALESCE($4, category),
         description = COALESCE($5, description),
         purchase_price = COALESCE($6, purchase_price),
         selling_price  = COALESCE($7, selling_price),
         quantity = COALESCE($8, quantity),
         min_stock_level = COALESCE($9, min_stock_level),
         unit = COALESCE($10, unit)
       WHERE id = $11 AND user_id = $12 RETURNING *`,
      [name, sku, barcode, category, description,
       purchasePrice, sellingPrice, quantity, minStockLevel, unit,
       req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

// DELETE /api/products/:id (soft delete)
router.delete('/:id', async (req, res, next) => {
  try {
    const { rows } = await db(
      `UPDATE products SET is_active = false WHERE id = $1 AND user_id = $2 RETURNING id`,
      [req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, message: 'Product deleted' });
  } catch (err) { next(err); }
});

module.exports = router;
